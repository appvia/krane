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

# Understands how to compile risk rule defined in config/rules.yaml taking into account:
# macros, whitelist, custom_params, threshold, etc
# It resolves & builds graph query and writer expression based on rule attributes.

module Krane
  module Report
    module RiskRule
      class Resolver

        class RuleConfigError < StandardError; end

        def initialize cluster:, risk:, whitelist:
          @cluster   = cluster
          @risk      = risk
          @whitelist = whitelist
          @item      = nil
        end

        # Prepares a collection of validated and resolved/compiled risk rule Items
        # NOTE: disabled rules are automatically excluded from the collection
        def risk_rules
          @risk.rules.map { |rule| Item.new(resolve(rule)) }.compact.reject { |i| i.disabled? }
        end

        private

        def resolve item
          # Note: resolve order matters!
          # 1. macros    - expand rules with macros, and substitue any optional custom attributes in query / writer
          # 2. validate  - validate item
          # 3. query     - build graph query for specified template & match_rules if excplicit query not provided
          # 4. writer    - select templated or inline writer for the rule
          # 5. whitelist - substitue any whitelisted (templated) parameters in query / writer
          # 6. threshold - substitue threshold conditions in query / writer

          @item = item

          macros
          validate
          query
          writer
          custom_params
          whitelist
          threshold
          
          @item.symbolize_keys
        end

        # Resolves macros optionally referenced in risk rule item 
        def macros
          return unless @item.has_key?(:macro)
          
          macro = @risk.macros[@item[:macro]]

          return if macro.blank?

          # Currently :macro can override the following rule attributes:
          # - :query
          # - :writer
          # - :template
          @item[:query]    = macro[:query].dup    if macro.has_key?(:query)
          @item[:writer]   = macro[:writer].dup   if macro.has_key?(:writer)
          @item[:template] = macro[:template].dup if macro.has_key?(:template)
        end

        # Basic validation 
        def validate
          unless [@item[:query], @item[:writer]].all? || @item[:template].present?
            raise RuleConfigError.new("#{@item[:id]} - must define `query`&`writer` OR `template` fields!")
          end          
        end

        # Resolves :query based on :template & :match_rules definied for the risk rule item (unless explicit :query & :writer is provided)
        # Note: :query has precedence over :template
        def query
          return if @item[:query].present?     # when :query excplicitly defined then no need to resolve matchers
          @item[:query] = cleanup(Query::Builder.for(item: @item))
        end

        # Resolves writer based on :template defined for the risk rule item (only when no explicit :writer is provided)
        # Note: :writer has precedence over :template!
        def writer
          return if @item[:writer].present?   # when :writer explicitly defined then no need to resolve it
          @item[:writer] = cleanup(Query::Template.for(kind: @item[:template]).writer)
        end

        def custom_params
          # Swaps placeholders in :query/:writer with :custom_params defined for given risk
          # :custom_params keys map directly to placeholders in :query/:writer 
          # Example: For the following rule definition
          # 
          # ---
          # rules:
          # - id: some-rule
          #   custom_params:
          #    attrA: valueA
          #    attrB: valueB
          #
          # Placeholders `{{attrA}}` and `{{attrB}}` will be replaced with `valueA` and `valueB` respectively.
          # NOTE: attribute placeholders will only be swapped in :query or :writer!
          #
          if @item.has_key?(:custom_params) && @item[:custom_params].any?
            @item[:custom_params].each do |placeholder, value|
              substitute_placeholder @item[:query],  placeholder, value
              substitute_placeholder @item[:writer], placeholder, value
            end
          end
        end

        # Resolves optional whitelist for given risk rule item.
        # Whitelisted custom attributes are defined in config/whitelist.yaml and divided into 
        # three separate sections: 
        #   - global: top level scope, custom attributes defined here will apply to all risk rules regardless of the cluster name
        #   - common: custom attributes will be scoped to specific risk rule id regardless of the cluster name
        #   - clusters (with nested list of cluster names): custom attributes will apply to specific risk rule id in a given cluster name 
        
        # Keys of custom attributes specified for given risk rule id will be expanded
        # and placeholders with matching names will be replaced with their respective values.
        
        # Example:
        # ---
        # rules:
        #   global: # global scope - applies to all risk rule and cluster names
        #     whitelist_role_names: # custom attribute name
        #       - acp:prometheus:operator # custom attribute values

        #   common: # common scope - this will apply to specific risk rule id regardless of cluster name
        #     some-risk-rule-id:  # this corresponds to risk rule id defined in config/rules.yaml
        #       whitelist_subject_names: # custom attribute name
        #         - privileged-psp-users # custom attribute values

        #   cluster: # cluster scope - applied to speciifc risk rule id and cluster name
        #     default: # example cluster name
        #       some-risk-rule-id: # risk rule id 
        #         whitelist_subject_names: # custom attribute nane
        #           - privileged-psp-users # custom attribute values
        # 
        def whitelist
          @whitelist.for_risk_item(@item[:id], @cluster).each do |k, v|
            instance_variable_set("@#{k}", v)
          end

          @item[:query].gsub!(/{{(.*?)}}/) { instance_variable_get("@#{$1}") || [''] }
        end

        # Resolves :treshold risk rule attribue to a numeric value
        # {{threshold}} placeholder in writer will be replaced with numeric value
        def threshold
          # some report writers use threshold numeric value - accessible in writer block
          substitute_placeholder @item[:writer], 'threshold', @item.fetch(:threshold, 0).to_s
        end

        def substitute_placeholder str, placeholder, value
          str.gsub!("{{#{placeholder}}}") { value }
        end

        def cleanup str
          str.strip.gsub(/\s+/, ' ')
        end
      
      end
    end
  end
end
