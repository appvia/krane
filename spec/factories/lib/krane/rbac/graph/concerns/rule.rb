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

# This factory generates source representation of RBAC Role/ClusterRole rule

FactoryBot.define do
  factory :rule, class: Hash do

    factory :resource_rule do

      transient do
        api_groups     { [''] } # "" indicates the core API group
        resources      { ['configmaps'] }
        resource_names { ['my-configmap'] }
        verbs          { ['update', 'get'] }
      end

      skip_create
      initialize_with do
        {
          apiGroups:     api_groups, 
          resources:     resources,
          verbs:         verbs,
        }.tap do |h|
          h[:resourceNames] = resource_names unless resource_names.nil?
        end.with_indifferent_access
      end

    end

    factory :non_resource_rule do

      transient do
        non_resource_urls { ["/healthz", "/healthz/*"] } # '*' in a nonResourceURL is a suffix glob match
        verbs             { ['update', 'get'] }
      end

      skip_create
      initialize_with do
        {
          nonResourceURLs: non_resource_urls, 
          verbs:           verbs
        }.with_indifferent_access
      end

    end

  end
end
