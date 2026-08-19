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

# Understands how to build RBAC relationships graph in FalkorDB

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

        # RBAC kinds which are namespace scoped. Objects of these kinds are only unique
        # within a namespace, so the namespace must form part of their graph node identity.
        # Without it, same-named objects in different namespaces collapse into a single
        # node and their access rules merge.
        # Note: ClusterRole is cluster scoped, and User/Group are not namespaced in RBAC.
        NAMESPACED_KINDS = [:Role, :ServiceAccount].freeze

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
          # Internal lookup mapping a Role name to the set of namespaces it is defined in.
          # A role name is only unique within a namespace, so this cannot be a single value.
          @role_ns_lookup           = Hash.new { |h, k| h[k] = Set.new }
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

        # Generates a graph node label for an RBAC entity, including its namespace when the
        # entity's kind is namespace scoped. This is the single place that decides what makes
        # up an entity's graph identity - node and edge builders must both go through it, or
        # an edge will reference a label that no node declares.
        #
        # @param kind [Symbol/String] entity kind (:Role, :ClusterRole, :ServiceAccount, :User, :Group)
        # @param name [String] entity name
        # @param namespace [String] the entity's own namespace. Ignored for cluster scoped kinds.
        #
        # @return [String]
        def label_for kind, name, namespace = nil
          return make_label kind, name unless namespaced? kind
          make_label kind, name, namespace
        end

        # Returns whether entities of the given kind are namespace scoped
        #
        # @param kind [Symbol/String] entity kind
        #
        # @return [Boolean]
        def namespaced? kind
          NAMESPACED_KINDS.include? kind.to_s.to_sym
        end

        # Returns the identity of a role for set membership and lookup purposes
        # (@defined_roles, @default_roles, @referenced_roles, @undefined_roles).
        #
        # This must agree with #label_for on what makes a role distinct, otherwise the role
        # bookkeeping and the graph disagree - e.g. a Role defined in one namespace would be
        # treated as satisfying a binding that references the same name in another namespace,
        # leaving edges pointing at a graph node that was never created.
        #
        # @param kind [Symbol/String] :Role or :ClusterRole
        # @param name [String] role name
        # @param namespace [String] the role's own namespace. Ignored for :ClusterRole.
        #
        # @return [Hash]
        def role_identity kind, name, namespace = nil
          identity = { role_kind: kind.to_s.to_sym, role_name: name }
          identity[:role_namespace] = namespace if namespaced? kind
          identity
        end

      end
    end
  end
end
