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

# Understands how to prepare RBAC network graph source data for consumption in the UI

require 'json'

module Krane
  module Visualisations
    module NetworkView

      class Builder
        include Helpers

        def initialize options, nodes, edges
          @options = options
          @cluster = get_cluster_slug
          @nodes   = nodes
          @edges   = edges
        end

        def build
          dir = "#{Cli::Helpers::DATA_PATH}/#{@cluster}"
          FileUtils.mkdir_p dir
          File.write("#{dir}/rbac-network.json", prepare_network_data)
        end

        private

        def prepare_network_data
          {
            network_nodes: @nodes.to_a,
            network_edges: @edges.to_a
          }.to_json
        end

      end

    end
  end
end
