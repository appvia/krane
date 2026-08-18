# Copyright 2020 Appvia Ltd <info@appvia.io>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'json'
require 'time'
require 'fileutils'

# Understands how to persist the RBAC facets tree as chunked static JSON files
# the dashboard can load lazily.
#
# Layout under `data/{cluster}/tree`:
#
#   index.json           tree skeleton truncated at INDEX_DEPTH; truncated nodes
#                        carry `chunk` (where their children live) and `node_count`
#   search.json          term -> chunk lookup, so search can span unloaded chunks
#   {facet}/{slug}.json  the children of one truncated node
#   manifest.json        written last; its presence means every file it refers to
#                        is fully on disk
#
# Node contract: a node has `nodes` (inline children), or `chunk` (children live
# in another file), or neither (leaf). Nothing stops a chunk from itself holding
# `chunk` references, so splitting deeper later is not a format break.
module Krane
  module Visualisations
    module TreeView
      class Writer

        FORMAT_VERSION = 1

        # Depth at which the tree is cut into chunks, counting the root as 0.
        # That puts the cut below the facet wrappers, on nodes the UI only ever
        # reads once the user expands them.
        INDEX_DEPTH = 2

        # A chunk over this size is split again, heaviest branch first, so that
        # expanding one node fetches something a browser can parse without
        # stalling. Splitting at level 2 alone is not enough: on a real cluster a
        # single facet can hold tens of megabytes.
        MAX_CHUNK_BYTES = 256 * 1024

        # `{"nodes":[` and `]}` around the entries, and a comma between each.
        CHUNK_OVERHEAD = 12

        def initialize cluster:, tree:, root: nil
          @cluster = cluster
          @tree    = tree
          @root    = root || File.join(Cli::Helpers.data_root, cluster, 'tree')
          @slugs   = Hash.new(0)
          @chunks  = ['index.json'] # chunk 0 is the index itself
          @terms   = Hash.new { |h, k| h[k] = [] }
        end

        def write
          FileUtils.mkdir_p @root

          index = index_node(@tree, 0, nil) # writes the chunk files as it goes

          write_json 'index.json', index
          write_json 'search.json', {
            format_version: FORMAT_VERSION,
            chunks:         @chunks,
            terms:          @terms
          }

          prune keep: @chunks + ['search.json']

          # Written last so a reader that sees a manifest sees a complete set.
          write_json 'manifest.json', {
            format_version: FORMAT_VERSION,
            generated_at:   Time.now.utc.iso8601
          }

          @root
        end

        private

        # Copies the tree down to INDEX_DEPTH. Nodes at that depth have their
        # children written out to a chunk and replaced by a reference to it.
        def index_node node, depth, facet
          facet = node[:facet] if node[:facet].present?
          index_term node[:text], [0]

          children = node[:nodes]
          return node.except(:nodes) if children.blank?

          if depth < INDEX_DEPTH
            node.merge(nodes: children.map { |child| index_node(child, depth + 1, facet) })
          else
            node.except(:nodes).merge(write_chunk(children, facet: facet, name: node[:text], ancestors: []))
          end
        end

        # Writes `children` to their own file and returns the reference that
        # stands in for them. `ancestors` are the chunks a reader passes through
        # to get here, which is what lets search name an unopened branch.
        def write_chunk children, facet:, name:, ancestors:
          path = chunk_path(facet, name)
          @chunks << path
          chain = ancestors + [@chunks.size - 1]

          # Counted from the originals: node_count is the size of the whole
          # subtree, however many files it ends up spread across.
          node_count = children.sum { |child| count_nodes(child) }

          contents = pack(children, facet: facet, chain: chain)
          index_inline contents, chain
          write_json path, { nodes: contents }

          { chunk: path, node_count: node_count }
        end

        # Hands the heaviest branch its own chunk, over and over, until what is
        # left fits. Returns children with some of them replaced by references;
        # the originals are left alone.
        def pack children, facet:, chain:
          contents = children.dup
          weights  = contents.map { |child| weigh(child) }

          while (position = heaviest_splittable(contents, weights))
            child     = contents[position]
            reference = write_chunk(child[:nodes], facet: facet, name: child[:text], ancestors: chain)

            contents[position] = child.except(:nodes).merge(reference)
            weights[position]  = weigh(contents[position])
          end

          contents
        end

        # Which child to spin out next, or nil when the chunk fits — or when
        # nothing is left to split. A node whose children are all leaves cannot
        # be divided any further, so an oversized chunk is preferred to a lie.
        def heaviest_splittable contents, weights
          return nil if chunk_size(weights) <= MAX_CHUNK_BYTES

          contents.each_index
                  .select { |position| contents[position][:nodes].present? }
                  .max_by { |position| weights[position] }
        end

        # Bytes this node takes up in a chunk file.
        def weigh node
          node.to_json.bytesize
        end

        # Bytes the chunk file will be, from the weights of what is in it.
        def chunk_size weights
          weights.sum + CHUNK_OVERHEAD + [weights.size - 1, 0].max
        end

        def count_nodes node
          1 + (node[:nodes] || []).sum { |child| count_nodes(child) }
        end

        # Records every text held in this chunk against it and against the
        # chunks leading to it, so a match can be traced back to a branch the
        # reader has not opened yet.
        def index_inline nodes, chain
          nodes.each do |node|
            index_term node[:text], chain
            index_inline node[:nodes], chain if node[:nodes].present?
          end
        end

        def index_term text, chunk_indices
          return if text.blank?
          known = @terms[text.to_s.downcase]
          chunk_indices.each { |chunk_index| known << chunk_index unless known.include?(chunk_index) }
        end

        def chunk_path facet, text
          File.join(facet.to_s, "#{unique_slug(facet, text)}.json")
        end

        # Facet-scoped, filesystem-safe name for a node. Distinct nodes can slug
        # down to the same string ("[core] pods" and "core pods"), so repeats get
        # a numeric suffix rather than overwriting each other.
        def unique_slug facet, text
          slug = text.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
          slug = 'node' if slug.empty?

          seen = (@slugs["#{facet}/#{slug}"] += 1)
          seen == 1 ? slug : "#{slug}-#{seen}"
        end

        # Drops files left behind by an earlier run, so a cluster that shrinks
        # doesn't keep serving orphaned chunks. Never touches the manifest: it is
        # the previous run's commit marker until this run replaces it.
        def prune keep:
          kept = keep.map { |path| File.join(@root, path) } << File.join(@root, 'manifest.json')

          # Deepest first, so a directory is empty by the time we consider it.
          Dir.glob(File.join(@root, '**', '*')).sort.reverse_each do |path|
            if File.directory?(path)
              Dir.rmdir(path) if Dir.empty?(path)
            elsif !kept.include?(path)
              File.delete path
            end
          end
        end

        def write_json relative_path, data
          path = File.join(@root, relative_path)
          FileUtils.mkdir_p File.dirname(path)

          tmp = "#{path}.tmp"
          File.write tmp, data.to_json
          File.rename tmp, path # atomic: readers see the old or new file, never a partial one
        end

      end
    end
  end
end
