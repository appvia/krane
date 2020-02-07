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

# Understands how to build graph edges

require 'active_support/concern'

module Krane
  module Rbac
    module Graph
      module Concerns
        module Edges
          extend ActiveSupport::Concern

          included do
            extend Memoist

            # Maps graph buffer RBAC edges to string representation
            # 
            # @return [Array]
            memoize def edges
              @edge_buffer.map(&:to_s).compact
            end

            # Maps graph buffer RBAC edges to network representation
            # 
            # @return [Array]
            memoize def network_edges
              @edge_buffer.map(&:to_network).uniq.compact
            end

            private

            # Add relation (Edge) between two nodes to the graph edge buffer
            #
            # @param source_label [String] - source node label
            # @param relation [Symbol] - relation symbol (uppercased)
            # @param destination_label [String]  - destination node label
            # @param direction [String] - denotes the direction of relationship: <-, ->, <->
            #
            # @return [nil]
            def add_relation source_label, relation, destination_label, direction = '<->'
              # More popular nodes have more weigth
              @node_weights[source_label] += 1
              @node_weights[destination_label] += 1

              @edge_buffer << Edge.new(
                source_label:      source_label,
                relation:          relation,
                destination_label: destination_label,
                direction:         direction
              )
            end

            # Convenience method for edge creation
            #
            # @param kind [Symbol] - kind of edge to be created
            # @param params [Hash] - options for given edge kind
            #
            # @return [nil]
            def edge kind, params
              send("edge_#{kind.downcase}".to_sym, params)
            end

            # Adds :SCOPE edge between :Role (Role/ClusterRole) and :Namespace nodes
            #
            # @param role_kind [Symbol/String] :Role or :ClusterRole
            # @param role_name [String] - role name
            # @param namespace [String] - namespace name
            #
            # @return [nil]
            def edge_scope role_kind:, role_name:, namespace:
              role_label = make_label role_kind, role_name
              ns_label   = make_label namespace

              add_relation role_label, :SCOPE, ns_label
            end


            # Adds :ACCESS edge between :Subject and :Namespace nodes
            #
            # @param subject_kind [Symbol/String] :User, :Group, :ServiceAccount
            # @param subject_name [String] - subject name
            # @param namespace [String] - namespace name
            #
            # @return [nil]
            def edge_access subject_kind:, subject_name:, namespace:
              subject_label = make_label subject_kind, subject_name
              ns_label      = make_label namespace

              add_relation subject_label, :ACCESS, ns_label
            end

            # Adds :GRANT edge between :Role and :Rule (access definition) nodes
            #
            # @param role_kind [Symbol/String] :Role, :ClusterRole
            # @param role_name [String] - role name
            # @param rule [Hash] - access rule definition map
            #
            # @return [nil]
            def edge_grant role_kind:, role_name:, rule:
              role_label = make_label role_kind, role_name
              rule_label = make_label rule.values

              add_relation role_label, :GRANT, rule_label
            end

            # Adds :SECURITY edge between Role/ClusterRole rule and PodSecurityPolicy
            # NOTE: Edge will be created only for rules with `podsecuritypolicies` resource 
            #       and resource name specified.  
            #
            # @param rule [Hash] Role/ClusterRole access definiotion map
            #
            # @return [nil]
            def edge_security rule:
              # Only link access rules related to `podsecuritypolicies` resource, scoped to specific psp 
              if rule[:resource] == 'podsecuritypolicies' && !rule[:resource_name].nil?
                rule_label = make_label rule.values
                psp_label  = make_label 'psp', rule[:resource_name] # prepare label for PSP based on resource_name

                add_relation rule_label, :SECURITY, psp_label
              end
            end

            # Adds :ASSIGN edge between :Role and :Subject nodes
            #
            # @param role_kind [Symbol/String] :Role, :ClusterRole
            # @param role_name [String] - role name
            # @param subject_kind [Symbol/String] :User, :Group, :ServiceAccount
            # @param subject_name [String] - subject name
            #
            # @return [nil]
            def edge_assign role_kind:, role_name:, subject_kind:, subject_name:
              role_label    = make_label role_kind, role_name
              subject_label = make_label subject_kind, subject_name

              add_relation role_label, :ASSIGN, subject_label
            end

            # Adds :RELATION edge between two :Subject nodes
            #
            # @param a_subject_kind [Symbol/String] :User, :Group, :ServiceAccount
            # @param a_subject_name [String] - first subject name
            # @param b_subject_kind [Symbol/String] :User, :Group, :ServiceAccount
            # @param b_subject_name [String] - second subject name
            #
            # @return [nil]
            def edge_relation a_subject_kind:, a_subject_name:, b_subject_kind:, b_subject_name:
              a_subject_label = make_label a_subject_kind, a_subject_name
              b_subject_label = make_label b_subject_kind, b_subject_name

              add_relation a_subject_label, :RELATION, b_subject_label
            end

            # Adds :AGGREGATE edge between two :Role nodes (with ClusterRole kind)
            #
            # @param aggregating_role_name [String] - role name
            # @param composite_role_name [String] - subject name
            #
            # @return [nil]
            def edge_aggregate aggregating_role_name:, composite_role_name:
              # this edge can only be created for ClusterRoles
              aggregating_role_label = make_label :ClusterRole, aggregating_role_name
              composite_role_label   = make_label :ClusterRole, composite_role_name

              add_relation aggregating_role_label, :AGGREGATE, composite_role_label, '->'
            end

            # Adds :COMPOSITE edge between two :Role nodes (with ClusterRole kind)
            #
            # @param aggregating_role_name [String] - role name
            # @param composite_role_name [String] - subject name
            #
            # @return [nil]
            def edge_composite aggregating_role_name:, composite_role_name:
              # this edge can only be created for ClusterRoles
              aggregating_role_label = make_label :ClusterRole, aggregating_role_name
              composite_role_label   = make_label :ClusterRole, composite_role_name

              add_relation aggregating_role_label, :COMPOSITE, composite_role_label, '<-'
            end

          end # end included

        end
        
      end
    end
  end
end
