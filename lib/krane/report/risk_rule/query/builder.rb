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

module Krane
  module Report
    module RiskRule
      module Query
        module Builder
          extend self

          RISK_RULE_QUERY_EXCLUDE_DEFAULT_ROLES = true

          # Builds graph query based on :match_rules defined for the risk rule item (when no explicit :query is provided)
          # NOTE: Multiple :match_rules will be evaluated with logical AND
          #       so ONLY roles with intersecting matches will be selected
          #
          # :match_rules example:
          #
          # - apiGroups: ['*', 'core']
          #   resources: ['rolebindings', 'pods']
          #   verbs: ['patch', 'get']
          # - nonResourceURLs: ['/healthz']
          #   verbs: ['get']
          #
          def for item:
            if item[:match_rules].present?
              rule_selectors = build_rule_selectors(item: item)
              matches        = build_matches(rule_selectors: rule_selectors).join("\n")
              where          = build_where(rule_selectors: rule_selectors).join(' AND ')

              item[:query] = Template.for(kind: item[:template], matches: matches, where: where).query
            else
              item[:query] = Template.for(kind: item[:template]).query
            end
          end

          # Builds selectors for supplied risk item :match_rules
          # 
          # Returns an array of hashes containing rule selection attributes required to construct graph query matches
          # Example:
          #
          # [
          #   {:type=>"resource", :api_group=>"rbac.authorization.k8s.io", :resource=>"rolebindings", :verb=>"create"},
          #   {:type=>"resource", :api_group=>"rbac.authorization.k8s.io", :resource=>"roles", :verb=>"bind"}
          # ]
          #
          def build_rule_selectors item:
            item[:match_rules].collect do |match_rule|
              RuleSelector.new(match_rule).selectors
            end.flatten
          end

          # Builds graph query MATCH statements for supplied list of selectors    
          def build_matches rule_selectors: []
            exclude_default_roles = ENV.fetch(
              'RISK_RULE_QUERY_EXCLUDE_DEFAULT_ROLES', RISK_RULE_QUERY_EXCLUDE_DEFAULT_ROLES
            ).to_s == 'true'

            role_attrs = exclude_default_roles ? "{is_default: 'false'}" : ''

            rule_selectors.collect.with_index do |selector, index|
              rule_selector = selector.map do |k,v|
                "#{k}: '#{v}'"
              end.join(', ')

              "MATCH (ns:Namespace)<-[:SCOPE]-(ro#{index}:Role #{role_attrs})<-[:GRANT]-(:Rule {#{rule_selector}})"
            end
          end

          # Builds graph query WHERE condition for multi-MATCH queries
          def build_where rule_selectors: []
            return [] if rule_selectors.size == 1

            0.upto(rule_selectors.size-2).collect do |index|
              "ID(ro0) = ID(ro#{index+1})"
            end
          end

        end
      end
    end
  end
end
