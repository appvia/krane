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

# Understands how to decode a FalkorDB compact result set
#
# The compact encoding replaces property and label names with their positional
# id in the graph's schema, so decoding a row means resolving those ids against
# the property keys the graph reports.

module Krane
  module Clients
    module FalkorDB
      class QueryResult

        # Value types the compact protocol tags scalars with.
        NULL    = 1
        STRING  = 2
        INTEGER = 3
        BOOLEAN = 4
        DOUBLE  = 5
        ARRAY   = 6
        EDGE    = 7
        NODE    = 8

        # Column kinds the header tags each returned column with.
        COLUMN_SCALAR = 1
        COLUMN_NODE   = 2
        COLUMN_EDGE   = 3

        # Where properties sit within an encoded node and an encoded edge.
        NODE_PROPERTIES = 2
        EDGE_PROPERTIES = 4

        attr_reader :columns, :resultset

        def initialize response, graph:
          @graph = graph

          # A query that returns nothing - CREATE, an index - answers with
          # statistics alone.
          header, rows = response.length > 1 ? response : [nil, nil]

          @columns   = header ? header.map { |(_kind, name)| name } : nil
          @resultset = header ? rows.map { |row| decode_row(header, row) } : nil
        end

        private

        def decode_row header, row
          header.each_with_index.map do |(kind, _name), i|
            case kind
            when COLUMN_SCALAR then decode_scalar(*row[i])
            when COLUMN_NODE   then decode_properties row[i][NODE_PROPERTIES]
            when COLUMN_EDGE   then decode_properties row[i][EDGE_PROPERTIES]
            end
          end
        end

        def decode_scalar type, value
          case type
          when NULL    then nil
          when STRING  then value.to_s
          when INTEGER then value.to_i
          when BOOLEAN then value.to_s == 'true'
          when DOUBLE  then value.to_f
          when ARRAY   then value.map { |element| decode_scalar(*element) }
          when NODE    then decode_properties value[NODE_PROPERTIES]
          when EDGE    then decode_properties value[EDGE_PROPERTIES]
          end
        end

        # @return [Hash] property name to decoded value
        def decode_properties properties
          properties.to_h do |key_id, type, value|
            [ property_key(key_id), decode_scalar(type, value) ]
          end
        end

        # A query can mention a property created after the keys were last read,
        # so an id past the end of the cache means the cache is stale.
        def property_key key_id
          keys = @graph.property_keys

          if key_id >= keys.length
            @graph.invalidate_property_keys
            keys = @graph.property_keys
          end

          keys[key_id]
        end

      end
    end
  end
end
