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
          # @return [Array] an array of rule attribute selectors
          def selectors
            if resource_rule? # Resource specific rules
              i = [{type: 'resource'}]
              i = i.product(api_groups) if api_groups.any?
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

          def api_groups
            @api_groups.map {|i| {api_group: i}}        
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
