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

# Understands how to process role/clusterrole rules

require 'active_support/concern'

module Krane
  module Rbac
    module Graph
      module Concerns
        module RoleAccessRules
          extend ActiveSupport::Concern

          included do

            # Helper method processing rule
            #
            # @param rule [Hash] - Role/ClusterRole rule definition
            #
            # @return [Array]
            def process_rule rule
              if rule.has_key? 'apiGroups'
                process_resource_rule rule
              elsif rule.has_key? 'nonResourceURLs'
                process_non_resource_rule rule
              end
            end

            # Helper method processing resource rule 
            #
            # @param rule [Hash] - Role/ClusterRole resource rule definition
            #
            # @return [Array]
            def process_resource_rule rule
              buff = []
              rule['apiGroups'].each do |apigroup|
                group = apigroup.blank? ? 'core' : apigroup
                rule['resources'].each do |resource|
                  rule['verbs'].each do |verb|
                    (rule['resourceNames'] || ['']).each do |resource_name|
                      r = {type: 'resource', api_group: group, verb: verb, resource: resource}
                      r.merge!(resource_name: resource_name) unless resource_name.blank?
                      buff << r
                    end
                  end
                end
              end
              buff
            end

            # Helper method processing non-resource rule 
            #
            # @param rule [Hash] - Role/ClusterRole non-resource rule definition
            #
            # @return [Array]
            def process_non_resource_rule rule
              buff = []
              rule['nonResourceURLs'].each do |url|
                rule['verbs'].each do |verb|
                  buff << {type: 'non-resource', url: url, verb: verb}
                end
              end
              buff
            end

          end # end included

        end
        
      end
    end
  end
end
