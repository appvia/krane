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

# This factory generates source representation of RBAC RoleBinding/ClusterRoleBinding

FactoryBot.define do

  factory :subject, class: Hash do
    transient do
      kind      { :Group }
      name      { 'subject-name' }
      namespace { 'some-namespace' }
    end

    trait :group do
      transient do
        kind { :Group }
      end
    end

    trait :user do
      transient do
        kind { :User }
      end
    end

    trait :service_account do
      transient do
        kind { :ServiceAccount }
      end
    end

    skip_create
    initialize_with do
      {
        kind:      kind,
        apiGroup:  "rbac.authorization.k8s.io",
        name:      name,
      }.tap do |h|
        h[:namespace] = namespace unless namespace.blank?
      end.with_indifferent_access
    end
  end

  factory :role_ref, class: Hash do
    transient do
      kind  { :Role }
      name  { 'role-name' }
    end

    trait :cluster_role do
      transient do
        kind { :ClusterRole }
      end
    end

    trait :role do
      transient do
        kind { :Role }
      end
    end

    skip_create
    initialize_with do
      {
        apiGroup: "rbac.authorization.k8s.io",
        kind:     kind,
        name:     name
      }.with_indifferent_access
    end
  end

  factory :binding, class: Hash do

    transient do
      kind               { :RoleBinding }
      name               { 'rolebinding-name' }
      namespace          { 'some-namespace' }
      resource_version   { '271831670' }
      creation_timestamp { '2017-09-29T16:21:33Z' }
      subjects           { build_list(:subject, 1) }
      role_ref           { build(:role_ref) }
    end

    trait :for_cluster_role do
      transient do
        kind      { :ClusterRoleBinding }
        namespace { nil }
      end
    end

    trait :for_role do
      transient do
        kind      { :RoleBinding }
        namespace { 'some-namespace' }
      end
    end

    skip_create
    initialize_with do
      {
        metadata: {
          name:     name,
          selfLink: "/apis/rbac.authorization.k8s.io/v1/namespaces/#{namespace}/#{kind.to_s.downcase}s/#{name}",
          uid:      "657a44de-f6f4-11e8-980c-06f71a9d5a44",
          resourceVersion:   resource_version,
          creationTimestamp: creation_timestamp,
        }.tap { |h| h[:namespace] = namespace unless namespace.blank? },
        subjects: subjects,
        roleRef:  role_ref
      }.with_indifferent_access
    end
  end
end
