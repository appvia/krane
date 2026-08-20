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

          # Wildcard a role rule uses to mean "every API group", "every resource" or "every verb".
          WILDCARD = '*'

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
          # alternatives, so a single selector carries all of them, rather than being multiplied out
          # into MATCHes that no role rule can satisfy at once.
          #
          # A selector value is either a single value the matched rule's property must equal, or a
          # list of alternatives any one of which will do. The API groups are always a list; a
          # resource or a verb becomes one because the `*` a role rule may grant in its place covers
          # the named value too.
          #
          # @return [Array] an array of rule attribute selectors
          def selectors
            if resource_rule? # Resource specific rules
              i = [{type: 'resource'}]
              i = i.product([{api_group: api_groups}]) if api_groups.any?
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
            with_wildcard(@api_groups.map {|i| i.blank? ? CORE_API_GROUP : i })
          end

          def resources
            @resources.map {|i| {resource: with_wildcard(i)}}
          end

          def verbs
            @verbs.map {|i| {verb: with_wildcard(i)}}
          end

          # Non-resource URLs are left as written: RBAC matches them by prefix, so `*` is one of
          # several patterns a role rule may use to cover a URL and singling it out would be
          # arbitrary. No shipped rule matches on them.
          def urls
            @non_resource_urls.map {|i| {url: i}}
          end

          # A role rule granting the wildcard grants whatever the match rule names, so accept it
          # alongside. Values already asking for the wildcard are left as they are.
          def with_wildcard values
            (Array(values) + [WILDCARD]).uniq
          end

        end

      end
    end
  end
end
