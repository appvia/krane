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
  factory :risk, class: Krane::Config::Risk do

    transient do

      #== Initial rules/macros values for default and custom definitions  

      default { { rules: [], macros: {} } }
      custom  { { rules: [], macros: {} } }

      #== Default risk rule examples

      default_rule_id            { 'rule-id' }
      default_rule_query         { 'rule-query' }
      default_rule_writer        { 'rule-writer' }
      default_rule_severity      { :danger }
      default_rule_disabled      { false }
      default_rule_custom_params { {} }
      default_rule_threshold     { nil }

      default_query_based_rule do
        {
          id:            default_rule_id, 
          query:         default_rule_query, 
          writer:        default_rule_writer, 
          info:          "q-rule-info",
          severity:      default_rule_severity,
          disabled:      default_rule_disabled,
          group_title:   "q-group-title",
          custom_params: default_rule_custom_params,
          threshold:     default_rule_threshold,
        }
      end

      default_rule_template  { 'tpl-rule-template' }
      default_rule_match_rules do
        [
          {
            resources: ['secrets'],
            verbs: ['list']
          }
        ]
      end

      default_template_based_rule do
        {
          id:            default_rule_id, 
          info:          "tpl-rule-info",
          template:      default_rule_template,
          severity:      default_rule_severity,
          disabled:      default_rule_disabled,
          group_title:   "tpl-group-title",
          match_rules:   default_rule_match_rules,
          custom_params: default_rule_custom_params,
          threshold:     default_rule_threshold,
        }
      end

      #== Custom risk rule examples

      custom_rule_id            { 'rule-id' }
      custom_rule_query         { 'rule-query' }
      custom_rule_writer        { 'rule-writer' }
      custom_rule_severity      { :danger }
      custom_rule_disabled      { false }
      custom_rule_custom_params { {} }
      custom_rule_threshold     { nil }


      custom_query_based_rule do
        {
          id:            custom_rule_id, 
          query:         custom_rule_query, 
          writer:        custom_rule_writer, 
          info:          "q-rule-info",
          severity:      custom_rule_severity,
          disabled:      custom_rule_disabled,
          group_title:   "q-group-title",
          custom_params: custom_rule_custom_params,
          threshold:     custom_rule_threshold,
        }
      end

      custom_rule_template  { 'tpl-rule-template' }
      custom_rule_match_rules do
        [
          {
            resources: ['secrets'],
            verbs: ['list']
          }
        ]
      end

      custom_template_based_rule do
        {
          id:            custom_rule_id, 
          info:          "tpl-rule-info",
          template:      custom_rule_template,
          severity:      custom_rule_severity,
          disabled:      custom_rule_disabled,
          group_title:   "tpl-group-title",
          match_rules:   custom_rule_match_rules,
          custom_params: custom_rule_custom_params,
          threshold:     custom_rule_threshold,
        }
      end

      #== Example for macro

      default_macro_name  { 'macro_name' }
      default_macro_query { 'default_macro_query' }

      default_macro do
        {      
          default_macro_name => {
            query:  default_macro_query,
            writer: 'macro-writer'
          }
        }
      end

      custom_macro_name  { 'macro_name' }
      custom_macro_query { 'custom_macro_query' }

      custom_macro do
        {      
          custom_macro_name => {
            query:  custom_macro_query,
            writer: 'macro-writer'
          }
        }
      end

    end

    #== Entire rules & macros overrides

    trait :without_any_rules do
      after(:build) do |r, evaluator| 
        evaluator.default.delete(:rules)
        evaluator.custom.delete(:rules)
      end
    end

    trait :with_default_and_custom_rules do
      after(:build) do |r, evaluator| 
        evaluator.default[:rules] << evaluator.default_query_based_rule
        evaluator.custom[:rules]  << evaluator.custom_query_based_rule
      end
    end

    #== Inject rule to the default or custom set

    trait :with_default_query_based_rule do
      after(:build) do |r, evaluator|
        evaluator.default[:rules] << evaluator.default_query_based_rule
      end
    end
    trait :with_custom_query_based_rule do
      after(:build) do |r, evaluator|        
        evaluator.custom[:rules] << evaluator.custom_query_based_rule
      end
    end

    trait :with_default_template_based_rule do
      after(:build) do |r, evaluator| 
        evaluator.default[:rules] << evaluator.default_template_based_rule
      end
    end
    trait :with_custom_template_based_rule do
      after(:build) do |r, evaluator| 
        evaluator.custom[:rules] << evaluator.default_template_based_rule
      end
    end

    #== Inject macro to the default or custom set

    trait :with_default_macro do
      after(:build) do |r, evaluator| 
        evaluator.default[:macros].merge!(evaluator.default_macro)
      end
    end
    trait :with_custom_macro do
      after(:build) do |r, evaluator| 
        evaluator.custom[:macros].merge!(evaluator.custom_macro)
      end
    end

    #== Ensure instance variables are set correctly

    after(:build) do |r, evaluator|
      r.instance_variable_set(:@default, evaluator.default)
      r.instance_variable_set(:@custom, evaluator.custom)
    end

    skip_create
  end
end
