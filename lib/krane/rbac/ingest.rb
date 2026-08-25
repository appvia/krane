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

# Understands how to retrieve, cache and index RBAC relationships in FalkorDB

require 'yaml'
require 'fileutils'

module Krane
  module Rbac
    class Ingest
      include Helpers

      RBAC_CACHE_DIR = File.expand_path(File.join(File.dirname(__FILE__), '../../../', 'cache'))

      # PodSecurityPolicy (policy/v1beta1) was removed from Kubernetes in 1.25
      PSP_REMOVED_IN = Gem::Version.new('1.25')

      def initialize options
        @options    = options
        @cluster    = get_cluster_slug
        @graph      = get_graph_client
        @cache_path = [ RBAC_CACHE_DIR, @cluster ].join('/') # default cache path

        begin
          @graph.delete unless @options.noindex
        rescue Clients::FalkorDB::Graph::DeleteError => e
          banner :info, "#{e.message}. Graph `rbac-#{@cluster}` will be created." unless test?
        end
      end    

      def run
        cache_rbac
        return nil if @options.noindex # Stop further processing if --noidex flag was used
        index_rbac
      end

      private

      def cache_rbac
        if @options.incluster || @options.kubecontext.present?
          fetch_rbac # Fetch RBAC from running cluster, either directly in-cluster or with specified kube context
          banner :info, "RBAC fetched from running cluster and stored in cache directory: #{@cache_path}" unless test?
        elsif @options.dir.present?
          # @todo: validate whether supplied cache directory contains all required objects!
          @cache_path = @options.dir # Ingest from local cache directory
          banner :info, "Set RBAC cache path to: #{@cache_path}" unless test?
        end
      end

      def index_rbac
        k8s = Clients::Kubernetes.new(@options)

        graph = build_graph(@cache_path) do
          bootstrap_nodes
          psp if psp_supported?(k8s)
          roles
          cluster_roles
          role_bindings
          cluster_role_bindings
        end

        create_graph graph

        {
          undefined_roles:          graph.undefined_roles,
          unused_roles:             graph.unused_roles,
          bindings_without_subject: graph.bindings_without_subject,
          rbac_graph_network_nodes: graph.network_nodes,
          rbac_graph_network_edges: graph.network_edges
        }
      end

      # Writes the built graph out to FalkorDB: the nodes first, then the indexes the
      # edge statements match those nodes back through, then the edges.
      #
      # This is issued as a series of batched statements rather than the single
      # `CREATE <whole graph>` it replaced, which cost FalkorDB hundreds of megabytes
      # to parse and apply - enough to have it killed under the memory limit krane
      # ships with, on a cluster no larger than a few hundred roles.
      #
      # Batching gives up that statement's atomicity, so a failure part way through
      # would otherwise leave a partial graph behind for the report to read as if it
      # were complete. Discard it and let the failure surface.
      #
      # @param graph [Graph::Builder] the built RBAC graph
      #
      # @return [nil]
      def create_graph graph
        node_statements = graph.node_statements
        edge_statements = graph.edge_statements

        if @options.debug
          banner :debug, "Graph size = #{(node_statements + edge_statements).sum(&:bytesize)} bytes " \
                         "in #{node_statements.size} node and #{edge_statements.size} edge statements"
        end

        report_skipped_edges graph.skipped_edges

        node_statements.each {|statement| @graph.query(statement) }
        create_indexes graph.node_kinds
        edge_statements.each {|statement| @graph.query(statement) }

        nil
      rescue StandardError
        discard_graph
        raise
      end

      # An edge can name an entity the cluster never defines - a role granting use of
      # a PodSecurityPolicy that does not exist, say. Such an edge is left out of the
      # graph, which is worth saying out loud rather than passing over in silence.
      #
      # @param skipped [Array<Graph::Edge>] the edges left out
      #
      # @return [nil]
      def report_skipped_edges skipped
        return nil if skipped.empty?

        relations = skipped.map(&:relation).tally.map {|relation, count| "#{relation} x#{count}" }.join(', ')
        banner :warn, "Left #{skipped.size} graph edge(s) out, as they refer to an entity " \
                      "the cluster never defines (#{relations})."

        nil
      end

      # @param node_kinds [Array<Symbol>] the kinds of node the graph holds
      #
      # @return [nil]
      def create_indexes node_kinds
        node_kinds.each do |kind|
          @graph.query(%Q(CREATE INDEX ON :#{kind}(#{Graph::Builder::NODE_KEY})))
        end

        @graph.query(%Q(CREATE INDEX ON :Namespace(name)))
        @graph.query(%Q(CREATE INDEX ON :Subject(name)))
        @graph.query(%Q(CREATE INDEX ON :Role(name)))
        @graph.query(%Q(CREATE INDEX ON :Rule(name)))

        nil
      end

      # Removes whatever a failed ingest managed to create.
      #
      # Swallows anything that goes wrong here. Whatever failed the ingest is the
      # useful diagnostic, and it is raised by the caller once this returns - a tidy
      # up that fails in turn, because nothing was created yet or because the graph
      # went away with the connection, must not take its place.
      #
      # @return [nil]
      def discard_graph
        @graph.delete
      rescue StandardError
        nil
      end

      # PodSecurityPolicies are only fetched and indexed for clusters that still serve them.
      # When the cluster version cannot be determined we skip them, as querying the removed
      # `policy/v1beta1` API on a modern cluster fails the whole report with a 404.
      def psp_supported? k8s
        k8s.version < PSP_REMOVED_IN
      rescue StandardError => e
        banner :warn, "Unable to determine Kubernetes version (#{e.message}). " \
                      "Skipping PodSecurityPolicy, removed in Kubernetes #{PSP_REMOVED_IN}."
        false
      end

      def build_graph(path, &block)
        Docile.dsl_eval(Graph::Builder.new(path: path, options: @options), &block)
      end

      def fetch_rbac
        k8s = Clients::Kubernetes.new(@options)

        info "-- Fetching RBAC from cluster"

        FileUtils.mkdir_p @cache_path

        File.write("#{@cache_path}/psp",                 k8s.psp.get_pod_security_policies(as: :raw))  if psp_supported?(k8s)
        File.write("#{@cache_path}/roles",               k8s.rbac.get_roles(as: :raw))
        File.write("#{@cache_path}/rolebindings",        k8s.rbac.get_role_bindings(as: :raw))
        File.write("#{@cache_path}/clusterroles",        k8s.rbac.get_cluster_roles(as: :raw))
        File.write("#{@cache_path}/clusterrolebindings", k8s.rbac.get_cluster_role_bindings(as: :raw))

        info "-- Fetching done"
      end

    end
  end
end

Krane::Rbac::Ingest.new(OpenStruct.new(cluster: ARGV[0], dir: ARGV[1])).run if __FILE__ == $0
