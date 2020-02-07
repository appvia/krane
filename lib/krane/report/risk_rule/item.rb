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

      class Item < Hashie::Dash
        # Required
        property :id,              required: true
        property :group_title,     required: true
        property :severity,        required: true
        property :info,            required: true
        property :query,           required: true
        property :writer,          required: true
         
        # Optional
        property :disabled,        default: false
        property :threshold,       default: nil
        property :macro,           default: nil
        property :template,        default: nil
        property :match_rules,     default: nil
        property :custom_params,   default: nil

        def disabled?
          return false unless respond_to? :disabled
          disabled
        end
      end

    end
  end
end
