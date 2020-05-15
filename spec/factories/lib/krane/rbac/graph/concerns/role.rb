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

# This factory generates source representation of RBAC Role/ClusterRole

FactoryBot.define do
  factory :role, class: Hash do

    transient do
      kind               { :Role }
      name               { 'role-name' }
      resource_version   { '271831670' }
      creation_timestamp { '2017-09-29T16:21:33Z' }
      labels             { {} }
      rules              { build_list(:resource_rule, 1) } 
      aggregation_rules  { nil }
      namespace          { 'some-namespace' }
    end

    factory :cluster_role do
      transient do
        kind      { :ClusterRole }
        namespace { nil }
      end

      trait :with_aggregate_to_labels do
        transient do
          labels do
            {
              "rbac.authorization.k8s.io/aggregate-to-admin": "true",
              "rbac.authorization.k8s.io/aggregate-to-edit": "true"
            }
          end
        end
      end

      trait :with_aggregation_rules do
        transient do
          aggregation_rules do
            {
              clusterRoleSelectors: [
                {
                  matchLabels: {
                    "rbac.authorization.k8s.io/aggregate-to-admin": "true"
                  }
                }
              ]
            }
          end
        end
      end
    end

    trait :default do
      transient do
        labels do 
          {
            "kubernetes.io/bootstrapping": "rbac-defaults"
          }
        end
      end
    end

    skip_create
    initialize_with do
      {
        metadata: {
          name:              name,
          selfLink:          "/apis/rbac.authorization.k8s.io/v1/#{kind.to_s.downcase}s/#{name}",
          uid:               "4423ac0e-d383-4ab1-b7ba-29ee5f8024c8",
          resourceVersion:   resource_version,
          creationTimestamp: creation_timestamp,
          labels:            labels
        }.tap {|h| h[:namespace] = namespace unless namespace.blank? },
        rules: rules,
      }.tap do |h| 
        h[:aggregationRule] = aggregation_rules unless aggregation_rules.blank?
      end.with_indifferent_access
    end
  end
end
