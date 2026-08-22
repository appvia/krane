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

            # Cypher statements creating every buffered RBAC edge, holding at most
            # `batch_size` relationships each.
            #
            # Nodes are created by their own statements, so an edge cannot be written as
            # a pattern over query scoped variables any more - it has to match both of
            # its nodes back first. Edges are grouped by everything a single pattern
            # fixes (the kind of node at either end, the relation and its direction), so
            # each statement reduces to one UNWIND over the node labels it links.
            #
            # @param batch_size [Integer] - maximum number of relationships per statement
            #
            # @return [Array<String>]
            def edge_statements batch_size: Builder::INGEST_BATCH_SIZE
              grouped_edges.flat_map do |(source_kind, relation, destination_kind, direction), labels|
                pattern = direction == '->' ?
                  %Q((s)-[:#{relation}]->(d)) :
                  %Q((s)<-[:#{relation}]-(d))

                labels.each_slice(batch_size).map do |batch|
                  pairs = batch.map {|source, destination| "['#{source}','#{destination}']" }.join(',')

                  "UNWIND [#{pairs}] AS pair " \
                  "MATCH (s:#{source_kind} {#{Builder::NODE_KEY}: pair[0]}), " \
                        "(d:#{destination_kind} {#{Builder::NODE_KEY}: pair[1]}) " \
                  "CREATE #{pattern}"
                end
              end
            end

            # Maps graph buffer RBAC edges to network representation
            # 
            # @return [Array]
            memoize def network_edges
              @edge_buffer.map(&:to_network).uniq.compact
            end

            private

            # Buffered edges keyed by the node kinds they connect, the relation and its
            # direction, mapping to the pairs of node labels related that way.
            #
            # Edges whose endpoints were never buffered as nodes are dropped - there is
            # nothing in the graph for them to attach to.
            #
            # @return [Hash]
            def grouped_edges
              @edge_buffer.each_with_object(Hash.new {|h,k| h[k] = [] }) do |e, grouped|
                source_kind      = node_kind_lookup[e.source_label]
                destination_kind = node_kind_lookup[e.destination_label]
                next unless source_kind && destination_kind

                e.directions.each do |direction|
                  grouped[[source_kind, e.relation, destination_kind, direction]] <<
                    [e.source_label, e.destination_label]
                end
              end
            end

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
              send("edge_#{kind.downcase}".to_sym, **params)
            end

            # Adds :SCOPE edge between :Role (Role/ClusterRole) and :Namespace nodes
            #
            # @param role_kind [Symbol/String] :Role or :ClusterRole
            # @param role_name [String] - role name
            # @param namespace [String] - namespace name. For a :Role this is also the role's
            #                             own namespace, so it forms part of the role's identity.
            #
            # @return [nil]
            def edge_scope role_kind:, role_name:, namespace:
              role_label = label_for role_kind, role_name, namespace
              ns_label   = make_label namespace

              add_relation role_label, :SCOPE, ns_label
            end


            # Adds :ACCESS edge between :Subject and :Namespace nodes
            #
            # @param subject_kind [Symbol/String] :User, :Group, :ServiceAccount
            # @param subject_name [String] - subject name
            # @param namespace [String] - the namespace the subject is being granted access to
            # @param subject_namespace [String] - the subject's own namespace. Distinct from
            #                                     :namespace above - a ServiceAccount in one
            #                                     namespace can be granted access to another.
            #
            # @return [nil]
            def edge_access subject_kind:, subject_name:, namespace:, subject_namespace: nil
              subject_label = label_for subject_kind, subject_name, subject_namespace
              ns_label      = make_label namespace

              add_relation subject_label, :ACCESS, ns_label
            end

            # Adds :GRANT edge between :Role and :Rule (access definition) nodes
            #
            # @param role_kind [Symbol/String] :Role, :ClusterRole
            # @param role_name [String] - role name
            # @param rule [Hash] - access rule definition map
            # @param namespace [String] - the role's own namespace
            #
            # @return [nil]
            def edge_grant role_kind:, role_name:, rule:, namespace: nil
              role_label = label_for role_kind, role_name, namespace
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
            # @param role_namespace [String] - the role's own namespace
            # @param subject_namespace [String] - the subject's own namespace
            #
            # @return [nil]
            def edge_assign role_kind:, role_name:, subject_kind:, subject_name:,
                role_namespace: nil, subject_namespace: nil
              role_label    = label_for role_kind, role_name, role_namespace
              subject_label = label_for subject_kind, subject_name, subject_namespace

              add_relation role_label, :ASSIGN, subject_label
            end

            # Adds :RELATION edge between two :Subject nodes
            #
            # @param a_subject_kind [Symbol/String] :User, :Group, :ServiceAccount
            # @param a_subject_name [String] - first subject name
            # @param b_subject_kind [Symbol/String] :User, :Group, :ServiceAccount
            # @param b_subject_name [String] - second subject name
            # @param a_subject_namespace [String] - first subject's own namespace
            # @param b_subject_namespace [String] - second subject's own namespace
            #
            # @return [nil]
            def edge_relation a_subject_kind:, a_subject_name:, b_subject_kind:, b_subject_name:,
                a_subject_namespace: nil, b_subject_namespace: nil
              a_subject_label = label_for a_subject_kind, a_subject_name, a_subject_namespace
              b_subject_label = label_for b_subject_kind, b_subject_name, b_subject_namespace

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
