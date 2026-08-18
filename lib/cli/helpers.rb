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

    APP_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '../..')).freeze

    # Absolute path to the dashboard data directory. DATA_PATH on its own only
    # resolves when the process happens to be running from the app root.
    def self.data_root
      File.join(APP_ROOT, DATA_PATH)
    end

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
      # The tree manifest is written last, so its presence means the tree chunks
      # it refers to are all on disk.
      [
        'tree/manifest.json',
        'rbac-findings.json',
      ].all? { |file| File.exist?(File.join(Helpers.data_root, cluster, file)) }
    end

  end
end
