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

# Understands how to process RoleBindings/ClusterRoleBindings

require 'active_support/concern'

module Krane
  module Rbac
    module Graph
      module Concerns
        module Bindings
          extend ActiveSupport::Concern

          included do

            # Iterates through RoleBindings and processes them
            #
            # @return [nil]
            def role_bindings
              iterate :rolebindings do |b|
                setup_binding binding_kind: :RoleBinding, binding: b
              end
            end

            # Iterates through ClusterRoleBindings and processes them
            #
            # @return [nil]
            def cluster_role_bindings
              iterate :clusterrolebindings do |b|
                setup_binding binding_kind: :ClusterRoleBinding, binding: b
              end
            end

            private

            # Set up Role/ClusterRole bindings and:
            # - Add relevant nodes and edges
            #
            # @param binding_kind [Symbol] - binding kind as :RoleBinding, :ClusterRoleBinding
            # @param binding [Hash] - RoleBinding / ClusterRoleBinding definition
            #
            # @return [nil]
            def setup_binding binding_kind:, binding:
              binding_name = binding['metadata']['name']
              namespace    = binding_kind == :RoleBinding ? binding['metadata']['namespace'] : Krane::Rbac::Graph::Builder::ALL_NAMESPACES_PLACEHOLDER
              role_kind    = binding['roleRef']['kind']
              role_name    = binding['roleRef']['name']

              info "-- Indexing [#{binding_kind}] #{binding_name}"
              
              # If role in binding hasn't been defined then it should be recorded
              register_undefined_role({
                role_kind:    role_kind, 
                role_name:    role_name, 
                binding_kind: binding_kind, 
                binding_name: binding_name 
              })
              
              if namespace.present?
                node :namespace, { name: namespace }
                # This is specifcally true for all ClusterRoles referred in the Role bindings!
                edge :scope, { role_kind: role_kind, role_name: role_name, namespace: namespace }
              end

              if !binding.has_key?('subjects') || binding['subjects'].blank?
                register_binding_without_subjects binding_kind, binding_name
                return
              end

              # Iterate thorugh subjects
              binding['subjects'].each do |subject|
                set_subject_relations({
                  subject:   subject,
                  role_kind: role_kind,
                  role_name: role_name
                }.tap {|h|
                  h[:binding_namespace] = namespace if namespace.present?
                })
              end

              set_relation_between_any_two_subjects(subjects: binding['subjects'])
            end


            # Adds :RELATION edge between any pair of subjects
            #
            # @param subjects [Array] - array of Subject hash objects (with kind & name keys)
            #
            # @return [nil]
            def set_relation_between_any_two_subjects subjects:
              subjects.combination(2).each do |a,b|
                edge :relation, {
                  a_subject_kind: a['kind'],
                  a_subject_name: a['name'],
                  b_subject_kind: b['kind'],
                  b_subject_name: b['name'],
                }
              end
            end

            # Sets relevant Subject nodes and edges
            # - Adds :Namespace, :Subject nodes
            # - Adds :ASSIGN, :ACCESS edges
            #
            # @param subjects [Hash] - Subject hash objects (with kind & name keys)
            # @param role_kind [Symbol] - role kind as :Role, :ClusterRole
            # @param role_name [String] - role name
            # @param binding_namespace [String] - namespace name specified in the binding
            #
            # @return [nil]
            def set_subject_relations subject:, role_kind:, role_name:, binding_namespace: nil
              # subject namespace is determined in the following priority order:
              # 1. role binding namespace
              # 2. role namespace
              # 3. if all above nil it defaults to ALL_NAMESPACES_PLACEHOLDER
              subject_namespace = if binding_namespace.present?
                binding_namespace
              else
                @role_ns_lookup.fetch(role_name, Krane::Rbac::Graph::Builder::ALL_NAMESPACES_PLACEHOLDER)
              end

              # Building up referenced roles
              @referenced_roles << {
                role_kind: role_kind.to_sym, 
                role_name: role_name
              }

              node :namespace, { name: subject_namespace }
              node :subject, { kind: subject['kind'], name: subject['name'] }
              
              edge :assign, { 
                role_kind: role_kind, 
                role_name: role_name, 
                subject_kind: subject['kind'], 
                subject_name: subject['name'] 
              }

              edge :access, {
                subject_kind: subject['kind'], 
                subject_name: subject['name'], 
                namespace: subject_namespace 
              }
            end

            # Caches undefined role and adds undefined :Role node 
            #
            # @param role_kind [Symbol] - role kind as :Role, :ClusterRole 
            # @param role_name [String] - role name
            # @param binding_kind [Symbol] - binding kind as :RoleBinding, :ClusterRoleBinding
            # @param binding_name [String] - binding name
            #
            # @return [nil]
            def register_undefined_role role_kind:, role_name:, binding_kind:, binding_name:
              return if @defined_roles.find do |r| 
                r[:role_kind] == role_kind.to_sym && r[:role_name] == role_name
              end

              # Add role to undefined roles dict
              @undefined_roles << { 
                role_kind:    role_kind, 
                role_name:    role_name, 
                binding_kind: binding_kind, 
                binding_name: binding_name 
              } 

              # Create missing Role node so it can be referred to by other entities
              # Missing Role node must have attribute {defined: 'false'} so we can filter it in queries
              node :role, { kind: role_kind, name: role_name, defined: false }
            end

            # Caches bindings without any subjects
            #
            # @param role_kind [Symbol] - role kind as :Role, :ClusterRole 
            # @param role_name [String] - role name
            # @param binding_kind [Symbol] - binding kind as :RoleBinding, :ClusterRoleBinding
            # @param binding_name [String] - binding name
            #
            # @return [nil]
            def register_binding_without_subjects binding_kind, binding_name
              @bindings_without_subject << {
                binding_kind: binding_kind,
                binding_name: binding_name
              }
            end

          end # end included

        end
        
      end
    end
  end
end
