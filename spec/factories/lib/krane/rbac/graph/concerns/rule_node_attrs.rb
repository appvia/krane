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

# This factory will generate :Rule graph node attributes
# as if it was processed by PodSecurityPolicies concern

FactoryBot.define do
  factory :rule_node_attrs, class: Hash do

    transient do
      verb          { 'get' }
    end

    trait :for_resource do

      transient do
        api_group     { 'core' }
        resource      { 'configmaps' }
        resource_name { 'my-configmap' }
      end

      initialize_with do
        {
          type:           'resource',
          api_group:      api_group.to_s,
          resource:       resource.to_s,
          verb:           verb.to_s
        }.tap do |h|
          h[:resource_name] = resource_name.to_s unless resource_name.blank?
        end.with_indifferent_access
      end

    end

    trait :for_non_resource do

      transient do
        url        { '/healthz' }
      end

      initialize_with do
        {
          type: 'non-resource', 
          url:  url.to_s,
          verb: verb.to_s,
        }.with_indifferent_access
      end
    end

  end
end


