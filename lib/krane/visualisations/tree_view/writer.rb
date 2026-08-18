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
          index_term node[:text], 0

          children = node[:nodes]
          return node.except(:nodes) if children.blank?

          if depth < INDEX_DEPTH
            node.merge(nodes: children.map { |child| index_node(child, depth + 1, facet) })
          else
            node.except(:nodes).merge(write_chunk(node, children, facet))
          end
        end

        # Writes `children` to their own file and returns the reference the
        # index node stands in for them with.
        def write_chunk node, children, facet
          path = chunk_path(facet, node[:text])
          @chunks << path
          chunk_index = @chunks.size - 1

          node_count = children.sum { |child| index_subtree(child, chunk_index) }

          write_json path, { nodes: children }

          { chunk: path, node_count: node_count }
        end

        # Records every text in the subtree against the chunk holding it, and
        # returns how many nodes that subtree contains.
        def index_subtree node, chunk_index
          index_term node[:text], chunk_index
          1 + (node[:nodes] || []).sum { |child| index_subtree(child, chunk_index) }
        end

        def index_term text, chunk_index
          return if text.blank?
          chunks = @terms[text.to_s.downcase]
          chunks << chunk_index unless chunks.include?(chunk_index)
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
