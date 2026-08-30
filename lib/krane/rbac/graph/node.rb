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

      class Node < Hashie::Dash
        property :label, required: true
        property :kind,  required: true
        property :attrs, required: true

        GRAPH_NETWORK_NODE_GROUP = {
          Namespace: 0,
          Rule:      1,
          Role:      2,
          Subject:   3,
          Psp:       4
        }

        GRAPH_NETWORK_NODE_GROUP_BOOST = {
          is_default:    10,
          is_aggregable: 20,
          is_composite:  30
        }

        # Returns string representation of an RBAC node
        #
        # @return [String]
        def to_s
          node_attrs = attrs.map {|k,v| "#{k.to_s}:'#{escape(v)}'"}.join(", ")
          %Q((#{label}:#{kind} {#{node_attrs}}))
        end

        # Returns network representation of an RBAC node
        #
        # @return [Hash]
        def to_network(node_weitghs: {})
          return nil if [:Psp,:Rule].include?(kind)

          # Generate network graph nodes (excluding Psp, Rule nodes)
          k = attrs[:kind] || kind   # get :kind from node attributes, or node kind
          l = attrs[:name] || label  # get :name from node attributes, or node label
          n = attrs[:namespace]      # namespace scoped entities only (:Role, :ServiceAccount)
          d = attrs[:is_default]     # :Role specific
          c = attrs[:is_composite]   # :Role specific
          a = attrs[:is_aggregable]  # :Role specific
          i = attrs[:aggregable_by]  # :Role specific

          # Namespace scoped entities are distinct nodes per namespace, so the namespace has to
          # appear in the label - without it two separate nodes render identically and the viewer
          # cannot tell them apart. Cluster scoped entities carry the all-namespaces placeholder,
          # which says nothing and is left out.
          l = "#{l} (#{n})" if n.present? && n.to_s != Builder::ALL_NAMESPACES_PLACEHOLDER

          title = if (kind == :Role)
            ["#{k}: #{l}"].tap do |t|
              t << "- Default role (Kubernetes or cloud provider managed)" if d
              t << "- Aggregates rules defined in other cluster roles" if c
              t << "- Can be aggregated by cluster roles: #{i}" if a
            end.join("\n")
          else
            "#{k}: #{l}"
          end

          group =  GRAPH_NETWORK_NODE_GROUP[kind]
          group += GRAPH_NETWORK_NODE_GROUP_BOOST[:is_default]    if d # default cluster role node
          group += GRAPH_NETWORK_NODE_GROUP_BOOST[:is_aggregable] if a # aggregable cluster role node
          group += GRAPH_NETWORK_NODE_GROUP_BOOST[:is_composite]  if c # composite cluster role node

          {
            id:    label.delete_prefix(Builder::NODE_LABEL_PREFIX),
            label: "#{k}: #{l}",
            group: group,
            value: node_weitghs[label],
            title: title
          }
        end

        private

        # Attribute values carry cluster-supplied strings (e.g. RoleBinding subject
        # names, which Kubernetes does not format-validate for User/Group kinds) and
        # are rendered into single-quoted Cypher literals executed verbatim by
        # Ingest#index_rbac - quotes and backslashes must be escaped here or a
        # crafted value breaks out of the literal and injects arbitrary Cypher.
        def escape value
          value.to_s.gsub(/['\\]/) { |c| "\\#{c}" }
        end
      end

    end
  end
end
