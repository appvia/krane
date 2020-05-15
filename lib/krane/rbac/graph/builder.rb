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

# Understands how to build RBAC relationships graph in RedisGraph

# Usage example:

# def build_graph(path, verbose=false, &block)
#   Docile.dsl_eval(Krane::Rbac::Graph::Builder.new(path: path, options: ...), &block)
# end

# path = File.expand_path(File.join(File.dirname(__FILE__), '../../', 'cache')) + '/default'

# build_graph(path) do
#   bootstrap_nodes
#   psp
#   roles
#   cluster_roles
#   role_bindings
#   cluster_role_bindings
# end

require 'docile'
require 'hashie'

module Krane
  module Rbac
    module Graph

      class Builder
        include Helpers
        include Concerns::Nodes
        include Concerns::Edges
        include Concerns::RoleAccessRules
        include Concerns::PodSecurityPolicies
        include Concerns::Roles
        include Concerns::Bindings
        extend Memoist

        ALL_NAMESPACES_PLACEHOLDER = '*'
        NODE_LABEL_PREFIX = 'n'

        attr_reader :defined_roles, :undefined_roles, :bindings_without_subject

        # New graph builder instance
        #
        # @param path [String] local RBAC cache directory
        # @param options [Options] command line options
        #
        # @return [nil]
        def initialize path:, options: nil
          @path                     = path
          @options                  = options
          @role_ns_lookup           = {}      # Internal lookup for Role's namespace
          @node_weights             = Hash.new { |h, k| h[k] = 0 } # holds information on Node weight (more weight to popular nodes)
          @labels                   = {}      # List all labels and their respective ID
          @labels_counter           = 0       # Internal initial ID counter for labels 
          @node_buffer              = Set.new # holds all graph Nodes
          @edge_buffer              = Set.new # holds all graph Edges
          @defined_roles            = Set.new # List of all defined roles
          @undefined_roles          = Set.new # List of all undefined roles which are referred to in bindings
          @referenced_roles         = Set.new # List of roles which are referenced and assigned to a Subject
          @bindings_without_subject = Set.new # List of bindings without any Subjects attached
          @default_roles            = Set.new # Local cache of default (built-in) roles
          @aggregable_roles         = Hash.new { |h, k| h[k] = Set.new } # Maps cluster role with aggregation rules to its composite roles
        end

        # Iterates over specific resource items
        #
        # @param resource [Symbol/String] resource name (psp, roles, clusterroles, rolebindings, clusterrolebindings)
        # @param &block - item processor
        #
        # @return [nil]
        def iterate resource, &block
          data = YAML.load_file "#{@path}/#{resource}" # cached file may be either in YAML or JSON format
          data['items'].each do |i|
            yield(i)
          end
          nil
        end

        # Returns RBAC graph body to be indexed in Graph database
        #
        # @return [String]
        memoize def body
          (nodes + edges).join(',')
        end

        # Returns RBAC graph body for the network view
        #
        # @return [String]
        memoize def network_body
          (network_nodes + network_edges).join(',')
        end

        # List of unused roles (contains roles which are defined but not referenced)
        # By default this list will exclude built-in (default) roles.
        #
        # @return [Set]
        memoize def unused_roles include_default: false
          if include_default
            @defined_roles - @referenced_roles
          else
            @defined_roles - @default_roles - @referenced_roles
          end
        end

        private

        # Gemerates graph node label
        # - used to reference nodes when creating edges 
        #
        # @param str [Array] node name elements
        #
        # @return [String]
        memoize def make_label *str
          label = str.flatten.compact.join('_').downcase.gsub(/\W/,'_')
          @labels[label] ||= "#{NODE_LABEL_PREFIX}#{(@labels_counter += 1)}"
        end

      end
    end
  end
end
