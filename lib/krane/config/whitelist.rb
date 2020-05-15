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

# Understands how to compile whitelist for the risk rules

module Krane
  module Config
    class Whitelist
      include Helpers

      def initialize
        @whitelist = load_config_yaml 'whitelist.yaml'
      end

      def for_risk_item id, cluster
        global_item_whitelist  = @whitelist.try(:[], :rules).try(:[], :global) || []
        common_item_whitelist  = @whitelist.try(:[], :rules).try(:[], :common).try(:[], id) || []
        cluster_item_whitelist = @whitelist.try(:[], :rules).try(:[], :cluster).try(:[], cluster).try(:[], id) || []

        [
          global_item_whitelist, 
          common_item_whitelist, 
          cluster_item_whitelist
        ].merge_hashes.transform_values { |v| v.flatten.compact.uniq.sort }
      end
    end
  end
end
