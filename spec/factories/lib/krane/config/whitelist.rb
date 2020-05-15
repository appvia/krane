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
  factory :whitelist, class: Krane::Config::Whitelist do

    transient do

      #== Initial whitelist rules

      whitelist { { rules: {} } }


      #== Example global config

      global_whitelist_key  { :whitelist_role_names }
      global_whitelist_vals { ['acp:prometheus:operator'] }
      global_config do  
        {
          global: {
            global_whitelist_key => global_whitelist_vals
          }
        }
      end

      #== Example common config

      common_rule_id        { :rule_id }
      common_whitelist_key  { :whitelist_role_names }
      common_whitelist_vals { ['acp:prometheus:operator'] }
      common_config do
        {
          common: {
            common_rule_id => {
              common_whitelist_key => common_whitelist_vals
            }
          }
        }
      end

      #== Example cluster specific config

      cluster_name           { :minikube }
      cluster_rule_id        { :rule_id }
      cluster_whitelist_key  { :whitelist_role_names }
      cluster_whitelist_vals { ['acp:prometheus:operator'] }
      cluster_config do
        {
          cluster: {
            cluster_name => {
              cluster_rule_id => {
                cluster_whitelist_key => cluster_whitelist_vals
              }
            }
          }
        }
      end

    end


    #== global whitelist config

    trait :with_global_config do
      after(:build) do |w, evaluator| 
        evaluator.whitelist[:rules].merge!(evaluator.global_config)
      end
    end

    #== common config

    trait :with_common_config do
      after(:build) do |w, evaluator| 
        evaluator.whitelist[:rules].merge!(evaluator.common_config)
      end
    end

    #== cluster specific config

    trait :with_cluster_config do
      after(:build) do |w, evaluator| 
        evaluator.whitelist[:rules].merge!(evaluator.cluster_config)
      end
    end

    #== Ensure instance variables are set correctly

    after(:build) do |w, evaluator|
      w.instance_variable_set(:@whitelist, evaluator.whitelist)
    end

    skip_create
  end
end
