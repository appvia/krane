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

module Cli
  module Helpers

    DATA_PATH = 'dashboard/compiled/data'

    def raise_on_cluster_missing options
      raise 'Cluster not defined. Use --cluster [CLUSTER_NAME] to define it.' if options.cluster.blank?
    end

    def raise_on_cluster_report_missing options
      return if dashboard_data_exists? options.cluster
      raise "There is no data to show for #{options.cluster} cluster. Run the report first: `krane report -c #{options.cluster}`"
    end

    def raise_on_missing_path_or_context options
      unless [options.dir, options.kubecontext, options.incluster].any?
        raise "Must provide one of flags: --dir [PATH], --kubecontext [CONTEXT] or --incluster."
      end
    end

    def dashboard_data_exists? cluster
      f = -> (file) do 
        File.exist?(File.join(File.expand_path(File.dirname(__FILE__)), '../../', file))
      end

      [
        f.call("#{DATA_PATH}/#{cluster}/rbac-tree.json"),
        f.call("#{DATA_PATH}/#{cluster}/rbac-findings.json"),
      ].all?
    end

  end
end
