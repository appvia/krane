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

# This factory will generate expected :Role graph node attributes

FactoryBot.define do
  factory :role_node_attrs, class: Hash do

    transient do
      kind          { :Role }
      name          { 'role-name' }
      version       { '271831670' }
      created_at    { '2017-09-29T16:21:33Z' }
      defined       { true }
      is_default    { true }
      is_composite  { true }
      is_aggregable { true }
      aggregable_by { [] }
    end

    trait :for_cluster_role do
      transient do
        kind { :ClusterRole }
      end
    end

    trait :for_undefined do
      transient do
        defined { false }
      end
    end
 
    skip_create
    initialize_with do
      { 
        kind:          kind,
        name:          name,
        version:       version,
        created_at:    created_at,
        defined:       defined,
        is_default:    is_default,
        is_composite:  is_composite,
        is_aggregable: is_aggregable,
        aggregable_by: aggregable_by
      }.symbolize_keys
    end
  end
end
