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

FactoryBot.define do
  factory :node, class: Krane::Rbac::Graph::Node do

    label { "label" }
    kind  { :Role }
    attrs do 
      {
        kind: :Role,
        name: 'example-role'
      }
    end 

    trait :invalid do
      unknown_property { "unknown_value" }
    end

    trait :namespace do
      kind { :Namespace }
      attrs do
        {
          name: 'some-namespace'
        }
      end
    end

    #== :Rule node specific traits begin

    trait :rule do
      kind { :Rule }
    end

    trait :resource do
      attrs do
        {
          type:          'resource',
          api_group:     'some-api-group',
          resource:      'some-api-group',
          verb:          'some-verb',
          resource_name: 'some-specific-resource-name'
        }
      end
    end

    trait :non_resource do
      attrs do
        {
          type: 'non-resource',
          url:  'some-url',
          verb: 'some-verb'
        }
      end
    end

    #== :Rule node specific traits end

    #== :Role node specific traits begin

    trait :role do
      kind { :Role }
    end

    trait :default do
      after(:build) { |r| r.attrs[:is_default] = true }
    end

    trait :not_default do
      after(:build) { |r| r.attrs[:is_default] = false }
    end

    trait :composite do
      after(:build) { |r| r.attrs[:is_composite] = true }
    end

    trait :not_composite do
      after(:build) { |r| r.attrs[:is_composite] = false }
    end

    trait :aggregable do
      after(:build) { |r| r.attrs[:is_aggregable] = true }
    end

    trait :not_aggregable do
      after(:build) { |r| r.attrs[:is_aggregable] = false }
    end

    trait :aggregable_by_roles do
      after(:build) { |r| r.attrs[:aggregable_by] = ['role1', 'role2'].join(', ') }
    end

    trait :not_aggregable_by_roles do
      after(:build) { |r| r.attrs[:aggregable_by] = '' }
    end

    #== :Role node specific traits end

    #== :Subject node specific traits begin

    trait :subject do
      kind { :Subject }
      attrs do
        {
          kind: :Group,
          name: 'some-group'
        }
      end
    end

    trait :group do
      after(:build) { |r| r.attrs[:kind] = :Group }
    end

    trait :service_account do
      after(:build) { |r| r.attrs[:kind] = :ServiceAccount }
    end

    trait :user do
      after(:build) { |r| r.attrs[:kind] = :User }
    end

    #== :Subject node specific traits end

    #== :Psp node specific traits begin

    trait :psp do
      kind { :Psp }
      attrs do
        attrs = {
          name:                     'psp-name',
          privileged:               false,
          allowPrivilegeEscalation: false,
          allowedCapabilities:      'NET_ADMIN,IPC_LOCK',
          volumes:                  'hostPath,secret',
          hostNetwork:              false,
          hostIPC:                  false,
          hostIPD:                  false, 
          runAsUser:                'RunAsAny',
          seLinux:                  'RunAsAny',
          supplementalGroups:       'RunAsAny',
          fsGroup:                  'RunAsAny',
          version:                  'some-version',
          created_at:               'created-at-timestamp'
        }
      end
    end

    trait :privileged do
      after(:build) { |r| r.attrs[:privileged] = true }
    end

    #== :Psp node specific traits end

    skip_create
    initialize_with { new(attributes) }
  end
end
