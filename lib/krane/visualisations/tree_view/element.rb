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

# Understands how to construct a RBAC facets tree view element

module Krane
  module Visualisations
    module TreeView
      class Element < Hashie::Mash

        ALL_NAMESPACES      = '* (All NS)'
        DEFAULT_ROLE_TAG    = 'Default'
        AGGREGABLE_ROLE_TAG = 'Aggregable'
        COMPOSITE_ROLE_TAG  = 'Composite'

        def build facets:, with_keys: []
          with_keys.each do |key|
            send(key, facets[key]) if respond_to?(key)
          end
        end

        def namespaces facet
          build_facet(facet) do
            add tag: :Namespace, text: namespace, resource_kind: :NAMESPACE
            add tag: :admits, text: subject_kind
            add tag: subject_kind, text: subject_name, resource_kind: :ACTOR
            add tag: :to, text: rule_type

            if resource_related?
              add tag: :resource, text: "[#{rule_api_group}] #{rule_resource}", resource_kind: :RESOURCE
              add tag: :'resource name', text: resource_name if resource_name.present?
            else
              add tag: :URL, text: rule_url, resource_kind: :RESOURCE
            end

            add tag: :action, text: rule_verb
            add tag: [:"defined by #{role_kind}", default_role, aggregable_role, composite_role].compact, text: role_name, resource_kind: :ROLE
          end
        end

        def subjects facet
          build_facet(facet) do
            add tag: :Actor, text: subject_kind
            add tag: subject_kind, text: subject_name, resource_kind: :ACTOR
            add tag: :'in namespace', text: namespace, resource_kind: :NAMESPACE
            add tag: :'has access to', text: rule_type

            if resource_related?
              add tag: :resource, text: "[#{rule_api_group}] #{rule_resource}", resource_kind: :RESOURCE
              add tag: :'resource name', text: resource_name if resource_name.present?
            else
              add tag: :URL, text: rule_url, resource_kind: :RESOURCE
            end

            add tag: :action, text: rule_verb
            add tag: [:"defined by #{role_kind}", default_role, aggregable_role, composite_role].compact, text: role_name, resource_kind: :ROLE
          end
        end

        def roles facet
          build_facet(facet) do
            add text: role_kind
            add tag: [role_kind, default_role, aggregable_role, composite_role].compact, text: role_name, resource_kind: :ROLE
            add tag: :'grants access to', text: rule_type

            if resource_related?
              add tag: :resource, text: "[#{rule_api_group}] #{rule_resource}", resource_kind: :RESOURCE
              add tag: :'resource name', text: resource_name if resource_name.present?
            else
              add tag: :URL, text: rule_url, resource_kind: :RESOURCE
            end

            add tag: :action, text: rule_verb
            add tag: :'in namespace', text: namespace, resource_kind: :NAMESPACE
            add tag: :to, text: subject_kind
            add tag: subject_kind, text: subject_name, resource_kind: :ACTOR
          end
        end

        def resources facet
          build_facet(facet) do
            add text: rule_type

            if resource_related?
              add tag: :resource, text: "[#{rule_api_group}] #{rule_resource}", resource_kind: :RESOURCE
              add tag: :'resource name', text: resource_name if resource_name.present?
            else
              add tag: :URL, text: rule_url, resource_kind: :RESOURCE
            end

            add tag: :action, text: rule_verb
            add tag: :'granted to', text: role_kind
            add tag: [role_kind, default_role, aggregable_role, composite_role].compact, text: role_name, resource_kind: :ROLE
            add tag: :'with actor', text: subject_kind
            add tag: subject_kind, text: subject_name, resource_kind: :ACTOR
            add tag: :'in namespace', text: namespace, resource_kind: :NAMESPACE
          end
        end

        private

        def build_facet(obj, &block)
          Docile.dsl_eval(FacetBuilder.new(facet: obj), &block)
        end

        def resource_related?
          rule_type == 'resource'
        end

        def namespace
          return ALL_NAMESPACES if namespace_name == '*'
          namespace_name
        end

        def resource_name
          return nil if rule_resource_name.blank? || rule_resource_name == 'NULL'
          rule_resource_name
        end

        def default_role
          role_is_default == 'true' ? DEFAULT_ROLE_TAG : nil
        end

        def aggregable_role
          role_is_aggregable == 'true' ? AGGREGABLE_ROLE_TAG : nil
        end

        def composite_role
          role_is_composite == 'true' ? COMPOSITE_ROLE_TAG : nil
        end

      end
    end
  end
end
