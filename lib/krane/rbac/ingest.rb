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

# Understands how to retrieve, cache and index RBAC relationships in RedisGraph

require 'yaml'
require 'fileutils'

module Krane
  module Rbac
    class Ingest
      include Helpers

      RBAC_CACHE_DIR = File.expand_path(File.join(File.dirname(__FILE__), '../../../', 'cache'))

      def initialize options
        @options    = options
        @cluster    = get_cluster_slug
        @graph      = get_graph_client
        @cache_path = [ RBAC_CACHE_DIR, @cluster ].join('/') # default cache path

        begin
          @graph.delete unless @options.noindex
        rescue RedisGraph::DeleteError => e
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
          psp if k8s.version < 1.25
          roles
          cluster_roles
          role_bindings
          cluster_role_bindings
        end

        banner :debug, "Graph size = #{graph.body.bytesize} bytes" if @options.debug

        @graph.query(%Q(CREATE #{graph.body}))
        @graph.query(%Q(CREATE INDEX ON :Namespace(name)))
        @graph.query(%Q(CREATE INDEX ON :Subject(name)))
        @graph.query(%Q(CREATE INDEX ON :Role(name)))
        @graph.query(%Q(CREATE INDEX ON :Rule(name)))

        {
          undefined_roles:          graph.undefined_roles,
          unused_roles:             graph.unused_roles,
          bindings_without_subject: graph.bindings_without_subject,
          rbac_graph_network_nodes: graph.network_nodes,
          rbac_graph_network_edges: graph.network_edges
        }
      end

      def build_graph(path, &block)
        Docile.dsl_eval(Graph::Builder.new(path: path, options: @options), &block)
      end

      def fetch_rbac
        k8s = Clients::Kubernetes.new(@options)

        info "-- Fetching RBAC from cluster"

        FileUtils.mkdir_p @cache_path

        File.write("#{@cache_path}/psp",                 k8s.psp.get_pod_security_policies(as: :raw))  if k8s.version < 1.25
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
