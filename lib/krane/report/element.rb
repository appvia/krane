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

# Understands how to construct a risk report element

module Krane
  module Report
    module Element
      extend self

      # Builds report element
      #
      # @param id [String] risk rule identifier
      # @param severity [Symbol] risk's severity
      # @param group_title [String] group title describing the risk
      # @param info [String] detailed information on how to mitigate the risk
      # @param data [Set/QueryResult] Set / Graph Query results 
      # @param writer [Proc] ruby lambda to format result items output
      #
      # @return [Hash] map containing results of risk rule evaluation
      def build id:, severity:, group_title:, info:, data:, writer:
        @data   = data
        @writer = writer
        @items  = query_result_items

        {
          id:          id,
          status:      @items.blank? ? :success : severity.to_sym,
          group_title: group_title.strip,
          info:        info.strip.gsub(/\s+/,' '),
          items:       @items.blank? ? nil : @items
        }
      end

      private

      # Iterates over query result items and call a writer for each element
      #
      # @return [Array] formatted risk result items
      def query_result_items
        if @data.is_a?(Set)
          elements = @data.to_a
        else
          columns  = @data.columns
          elements = @data.resultset
        end

        return nil if elements.blank?

        elements.to_a.collect do |r|
          record = if r.is_a?(Hash)
            r
          else 
            # redisgraph-rb doesn't return hash records so making one up
            columns.zip(r).to_h.with_indifferent_access
          end

          @writer.call(Hashie::Mash.new(record)).try(:strip).try(:gsub, /\s+/, ' ') if @writer
        end.compact.uniq
      end

    end
  end
end
