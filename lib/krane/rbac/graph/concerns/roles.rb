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

# Understands how to process Role/ClusterRole

require 'active_support/concern'

module Krane
  module Rbac
    module Graph
      module Concerns
        module Roles
          extend ActiveSupport::Concern

          included do

            # Iterates through Roles and processes them
            #
            # @return [nil]
            def roles
              iterate :roles do |r|
                setup_role role_kind: :Role, role: r
              end
            end

            # Iterates through ClusterRoles and processes them and
            # creates edges between aggregating and composite ClusterRoles
            #
            # @return [nil]
            def cluster_roles
              iterate :clusterroles do |r|
                setup_role role_kind: :ClusterRole, role: r
              end

              # For cluster roles with aggregation rules create an edge betweeen those roles
              @aggregable_roles.each do |aggregating_role, composite_roles|
                composite_roles.each do |composite_role|
                  edge :aggregate, {
                    aggregating_role_name: aggregating_role, 
                    composite_role_name:   composite_role
                  }
                  edge :composite, {
                    aggregating_role_name: aggregating_role,
                    composite_role_name:   composite_role
                  }
                end
              end
            end

            private

            # Set up Role/ClusterRole and:
            # - Add relevant :Namespace, :Role, :Rule nodes to the graph node buffer
            # - Add relevant :SCOPE, :GRANT, :SECURITY edges to the graph edge buffer
            #
            # @param role_kind [Symbol] - role kind as one of :Role, :ClusterRole
            # @param role [Hash] - Role/ClusterRole definition
            #
            # @return [nil]
            def setup_role role_kind:, role:
              role_info     = extract_role_attrs role: role
              role_name     = role_info[:role_name]
              version       = role_info[:version]
              created_at    = role_info[:created_at]
              is_default    = role_info[:is_default]
              is_composite  = role_info[:is_composite]
              is_aggregable = role_info[:is_aggregable]
              aggregable_by = role_info[:aggregable_by]

              info "-- Indexing [#{role_kind}] #{role_name}"

              cache_aggregable_roles aggregable_by: aggregable_by, role_kind: role_kind, role_name: role_name

              namespace = role_kind == :Role ? role['metadata']['namespace'] : Krane::Rbac::Graph::Builder::ALL_NAMESPACES_PLACEHOLDER

              # caching role namespace scope
              @role_ns_lookup[role_name] = namespace if role_kind == :Role 

              entry = {
                role_kind: role_kind,
                role_name: role_name
              }
              
              @defined_roles << entry # caching role as defined
              @default_roles << entry if is_default # cache default roles

              node :namespace, { name: namespace }
              node :role, { 
                kind:          role_kind, 
                name:          role_name, 
                is_default:    is_default, 
                is_composite:  is_composite,
                is_aggregable: is_aggregable, 
                aggregable_by: aggregable_by.join(', '),
                version:       version,
                created_at:    created_at 
              }
              edge :scope, { 
                role_kind: role_kind, 
                role_name: role_name, 
                namespace: namespace 
              }

              return if role_info[:rules].blank?

              # Iterating the Rules
              role_info[:rules].map {|rule| process_rule rule }.flatten.each do |rule|
                node :rule, { rule: rule }
                edge :grant, {
                  role_kind: role_kind,
                  role_name: role_name,
                  rule:      rule
                }
                edge :security, { rule: rule }
              end
            end


            # Helper method extracting role attributes
            #
            # @param role [Hash] - raw Role/ClusterRole object
            #
            # @return [nil]
            def extract_role_attrs role:
              {
                role_name:      role['metadata']['name'],
                version:        role['metadata']['resourceVersion'],
                created_at:     role['metadata']['creationTimestamp'],
                is_default:     role['metadata'].try(:[], 'labels').try(:[], 'kubernetes.io/bootstrapping') == 'rbac-defaults' || false,
                is_composite:   role.key?('aggregationRule'),
                aggregable_by:  role['metadata'].key?('labels') && role['metadata']['labels'].collect do |k, v|
                                  k =~ /rbac.authorization.k8s.io\/aggregate-to-(.*)/ && v == 'true' ? $1 : nil
                                end.compact || [],
                rules:          role['rules']
              }.tap do |h|
                h[:is_aggregable] = !h[:aggregable_by].empty?
              end
            end

            # Caches aggregable roles
            # Builds a cluster roles lookup mapping to aggregable cluster roles
            #
            # @param aggregable_by [Array] - array of roles which can aggregate role specified by kind and name
            # @param role_kind [Symbol] - list of roles which can be aggregared by the role 
            # @param role_name [String] - list of roles which can be aggregared by the role 
            #
            # @return [nil]
            def cache_aggregable_roles aggregable_by:, role_kind:, role_name:
              aggregable_by.each do |aggregating_role|
                @aggregable_roles[aggregating_role].add(role_name) if role_kind == :ClusterRole
              end
            end

          end # end included

        end
        
      end
    end
  end
end
