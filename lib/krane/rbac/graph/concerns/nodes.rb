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

# Understands how to build graph nodes

require 'active_support/concern'

module Krane
  module Rbac
    module Graph
      module Concerns
        module Nodes
          extend ActiveSupport::Concern

          included do
            extend Memoist

            # Cypher statements creating every buffered RBAC node, holding at most
            # `batch_size` nodes each.
            #
            # @param batch_size [Integer] - maximum number of nodes per statement
            #
            # @return [Array<String>]
            def node_statements batch_size: Builder::INGEST_BATCH_SIZE
              @node_buffer.each_slice(batch_size).map do |batch|
                "CREATE #{batch.map(&:to_s).join(',')}"
              end
            end

            # The distinct kinds of node the graph holds
            #
            # @return [Array<Symbol>]
            memoize def node_kinds
              @node_buffer.map(&:kind).uniq
            end

            # Maps graph buffer RBAC nodes to network representation
            # 
            # @return [Array]
            memoize def network_nodes
              @node_buffer.map {|n| n.to_network(node_weitghs: @node_weights)}.uniq.compact
            end

            # Adds initial :Namespace node to the graph node buffer
            # 
            # @return [nil]
            def bootstrap_nodes
              node :namespace, { name: Krane::Rbac::Graph::Builder::ALL_NAMESPACES_PLACEHOLDER }
            end

            private

            # Maps every node label to the kind of node it labels. Edge statements match
            # their nodes back by label once the nodes exist, and need the kind to do so
            # against the label scoped index rather than the whole graph.
            #
            # @return [Hash]
            memoize def node_kind_lookup
              @node_buffer.each_with_object({}) {|n, lookup| lookup[n.label] = n.kind }
            end

            # Add node of given kind to the graph node buffer
            #
            # @param kind [Symbol]  - kind of graph node
            # @param label [String] - graph node label
            # @param attrs [Hash]   - map of graph node attributes
            #
            # @return [nil]
            def add_node kind, label, attrs
              @node_buffer << Node.new(
                kind:  kind,
                label: label,
                attrs: attrs
              )
            end

            # Convenience method for node creation
            #
            # @param kind [Symbol] - kind of node to be created
            # @param params [Hash] - options for given node kind
            #
            # @return [nil]
            def node kind, params
              send("node_#{kind.downcase}".to_sym, **params)
            end

            # Creates :Role graph node for RBAC Role/ClusterRole
            #
            # @param kind [Symbol] - kind of node to be created
            # @param name [String] - kind of node to be created
            # @param namespace [String] - the role's own namespace. Part of the node identity
            #                             for :Role; ignored for the cluster scoped :ClusterRole.
            # @param version [String] - kind of node to be created
            # @param created_at [String] - kind of node to be created
            # @param defined [Bool] - kind of node to be created
            # @param is_default [Bool] - kind of node to be created
            # @param is_composite [Bool] - kind of node to be created
            # @param is_aggregable [Bool] - options for given node kind
            # @param aggregable_by [String] - options for given node kind
            #
            # @return [nil]
            def node_role(kind:, name:, namespace: nil, version: nil, created_at: nil, defined: true,
                is_default: false, is_composite: false, is_aggregable: false, aggregable_by: '')
              label = label_for kind, name, namespace

              # build a hash attributes for the node automatically
              attrs = (local_variables - [:label, :attrs]).each_with_object({}) do |p, hsh|
                hsh[p] = binding.local_variable_get(p)
              end

              add_node :Role, label, attrs
            end

            # Creates :Namespace graph node
            #
            # @param name [String] - kind of node to be created
            #
            # @return [nil]
            def node_namespace name:
              label = make_label name
              attrs = { name: name }

              add_node :Namespace, label, attrs
            end

            # Creates :Rule graph node for RBAC Role/ClusterRole rule
            #
            # @param rule [Hash] - RBAC access rule attributes map
            #
            # @return [nil]
            def node_rule rule:
              label = make_label rule.values
              attrs = rule # assign all rule attributes

              add_node :Rule, label, attrs
            end

            # Creates :Psp graph node for RBAC PodSecurityPolicy
            #
            # @param attrs [Hash] - PodSecurityPolicy node attributes
            #
            # @return [nil]
            def node_psp attrs:
              label = make_label 'psp', attrs[:name]

              add_node :Psp, label, attrs
            end


            # Creates :Subject graph node for subjects referenced in RoleBinging/ClusterRoleBinding
            #
            # @param kind [Symbol] - RBAC Subject kind (:User, :Group, :ServiceAccount)
            # @param name [String] - subject name
            # @param namespace [String] - the subject's own namespace. Part of the node identity
            #                             for :ServiceAccount; :User and :Group are not namespaced.
            #
            # @return [nil]
            def node_subject kind:, name:, namespace: nil
              label = label_for kind, name, namespace
              attrs = { name: name, kind: kind }
              attrs[:namespace] = namespace if namespaced?(kind) && namespace.present?

              add_node :Subject, label, attrs
            end

          end # end included

        end
        
      end
    end
  end
end
