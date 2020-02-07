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

# Understands how build source data for RBAC facets Tree view in the UI
module Krane
  module Visualisations
    module TreeView
      class Builder
        include Helpers

        def initialize options
          @options    = options
          @cluster    = get_cluster_slug
          @graph      = get_graph_client
          @facets     = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) } # nested hash
          @facet_keys = [
            :namespaces,
            :subjects,
            :roles,
            :resources
          ]
        end

        def build
          dir = "#{Cli::Helpers::DATA_PATH}/#{@cluster}"
          FileUtils.mkdir_p dir
          File.write("#{dir}/rbac-tree.json", prepare_data)
        end

        private

        def query_graph
          res = @graph.query(%Q(
            MATCH (ns:Namespace)<-[:ACCESS]-(s:Subject)-[:ASSIGN]->(r:Role)-[:GRANT]->(ru:Rule)
            RETURN ns.name as namespace_name,
                   s.kind as subject_kind, 
                   s.name as subject_name,
                   r.kind as role_kind, 
                   r.name as role_name,
                   r.is_default as role_is_default,
                   r.is_composite as role_is_composite,
                   r.is_aggregable as role_is_aggregable,
                   ru.type as rule_type, 
                   ru.api_group as rule_api_group, 
                   ru.resource as rule_resource,
                   ru.resource_name as rule_resource_name, 
                   ru.url as rule_url, 
                   ru.verb as rule_verb
            ORDER BY namespace_name,subject_kind,subject_name,role_kind,role_name,rule_resource
          ))

          [res.columns, res.resultset]
        end

        def prepare_data
          columns, results = query_graph

          # build facets for each element in resultset
          results.each do |record|
            Element.new(columns.zip(record).to_h)
             .build facets: @facets, with_keys: @facet_keys
          end
          
          wrap_facets
        end

        def wrap_facets
          {
            text: "#{@cluster} cluster",
            nodes: [
              {
                text: "Namespaces", # name
                nodes: @facets[:namespaces].collect {|k,v| prepare_node(:NAMESPACE, k, v)} # children
              },
              {
                text: "Actors", # name
                nodes: @facets[:subjects].collect {|k,v| prepare_node(:ACTOR, k, v)} # children
              },
              {
                text: "Roles", # name
                nodes: @facets[:roles].collect {|k,v| prepare_node(:ROLE, k, v)} # children
              },
              {
                text: "Resource Access", # name
                nodes: @facets[:resources].collect {|k,v| prepare_node(:RESOURCE, k, v)} # children
              },
            ]
          }.to_json
        end

        def prepare_node branch, key, elements, level=0
          tag           = [key[:tag] || ''].flatten
          text          = key[:text]
          resource_kind = key[:resource_kind]

          current_level = (level += 1)

          {
            branch: branch,
            text:   text,
            nodes:  elements.blank? ? nil : elements.sort_by {|item, _| item[:text]}
                                                    .collect {|ek, ev| prepare_node(branch, ek, ev, current_level)}
          }.tap do |n|
            n[:tags]          = tag
            n[:navigable]     = current_level > 2 ? false : true # we only want to be navigating up to max 2 levels down the tree
            n[:resource_kind] = resource_kind unless resource_kind.blank?
          end
        end

      end
    end
  end
end

Krane::Visualisations::TreeView::Builder.new(OpenStruct.new(cluster: ARGV[0])).build if __FILE__ == $0
