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

# Understands how to retrieve and compile Risk rules (default and custom)

module Krane
  module Config
    class Risk
      include Helpers

      def initialize
        @default = load_config_yaml 'rules.yaml'
        @custom  = load_config_yaml 'custom-rules.yaml'
      end

      def rules
        return @default[:rules] if @custom[:rules].blank?

        @custom[:rules].each_with_object(@default[:rules]) do |custom_rule, arr|
          rule = arr.find {|r| r[:id] == custom_rule[:id]}
          rule ? rule.deep_merge!(custom_rule) : arr << custom_rule
        end
      end

      def macros
        return @default[:macros] if @custom[:macros].blank?
        @default[:macros].deep_merge!(@custom[:macros])
      end
    end
  end
end
