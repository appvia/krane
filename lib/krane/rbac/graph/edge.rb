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

require 'hashie'

module Krane
  module Rbac
    module Graph
      class Edge < Hashie::Dash
        property :source_label,      required: true
        property :relation,          required: true
        property :destination_label, required: true
        property :direction,         required: true

        # Returns string representation of an RBAC edge
        #
        # @return [String]
        def to_s
          out = []
          out << %Q((#{source_label})-[:#{relation}]->(#{destination_label})) if direction.include?('->')
          out << %Q((#{source_label})<-[:#{relation}]-(#{destination_label})) if direction.include?('<-')
          out.join(',')
        end

        # Returns network representation of an RBAC edge
        #
        # @return [Hash]
        def to_network
          return nil unless [source_label, destination_label].all? && 
                            [:ACCESS, :ASSIGN, :AGGREGATE, :COMPOSITE].include?(relation)

          {
            from: source_label.delete_prefix(Builder::NODE_LABEL_PREFIX),
            to:   destination_label.delete_prefix(Builder::NODE_LABEL_PREFIX)
          }    
        end
      end
    end
  end
end
