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

# RuleSelector understands how to build Rule selectors

module Krane
  module Report
    module RiskRule
      module Query
        class RuleSelector

          # The core API group, spelled `""` in a Kubernetes role rule and stored as `core` in
          # the graph (see Rbac::Graph::Concerns::RoleAccessRules#process_resource_rule).
          CORE_API_GROUP = 'core'

          # Wildcard a role rule uses to mean "every API group".
          ANY_API_GROUP = '*'

          def initialize attrs = {}
            @non_resource_urls = attrs.fetch(:nonResourceURLs, [])
            @api_groups        = attrs.fetch(:apiGroups, [])
            @resources         = attrs.fetch(:resources, [])
            @verbs             = attrs.fetch(:verbs, [])
          end

          def resource_rule?
            @resources.any?
          end

          def non_resource_rules?
            !resource_rule?
          end

          # Builds RBAC Rule selectors based on instance attributes
          #
          # Every attribute apart from the API groups selects a single value, so the selectors are
          # the product of them - the query builder emits one graph MATCH per selector and requires
          # all of them to hit the same role. API groups are the exception: their entries are
          # alternatives, so they are carried on the selector as an :api_groups list for the builder
          # to match in a single condition, rather than being multiplied out into MATCHes that no
          # role rule can satisfy at once.
          #
          # @return [Array] an array of rule attribute selectors
          def selectors
            if resource_rule? # Resource specific rules
              i = [{type: 'resource'}]
              i = i.product([{api_groups: api_groups}]) if api_groups.any?
              i = i.product(resources)  if resources.any?
              i = i.product(verbs)      if verbs.any?
            else # Non-resource URLs rules
              i = [{type: 'non-resource'}]
              i = i.product(urls)       if urls.any?
              i = i.product(verbs)      if verbs.any?
            end

            i.map do |x|
              x.flatten.reduce(&:merge)
            end
          end

          private

          # API groups a role rule may name to be considered a match. `''`, as written in a
          # Kubernetes role rule, is normalised to the `core` the graph stores, and the `*` wildcard
          # is always accepted - a role rule granting every API group grants this one too.
          def api_groups
            return [] if @api_groups.empty?
            @api_groups.map {|i| i.blank? ? CORE_API_GROUP : i }.push(ANY_API_GROUP).uniq
          end

          def resources
            @resources.map {|i| {resource: i}}
          end

          def verbs
            @verbs.map {|i| {verb: i}}
          end

          def urls
            @non_resource_urls.map {|i| {url: i}}
          end
        end

      end
    end
  end
end
