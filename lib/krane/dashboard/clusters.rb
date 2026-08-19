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

require 'json'
require 'time'
require 'fileutils'

# Understands the dashboard's cluster manifest: which clusters have report data
# on disk, and which one the UI should open by default.
#
# The dashboard is a static site, so this file is how the browser discovers what
# it is allowed to fetch. It doubles as the allowlist the UI checks a `?cluster=`
# parameter against before putting it in a URL.
module Krane
  module Dashboard
    module Clusters
      extend self

      FILE = 'clusters.json'

      def path root: Cli::Helpers.data_root
        File.join(root, FILE)
      end

      # Records that `cluster` has report data as of now.
      def record cluster, root: Cli::Helpers.data_root
        update(root) do |manifest|
          entry = { 'name' => cluster, 'generated_at' => Time.now.utc.iso8601 }

          manifest['clusters'] = manifest['clusters']
                                   .reject { |c| c['name'] == cluster }
                                   .push(entry)
                                   .sort_by { |c| c['name'].to_s }

          manifest['default'] = cluster if manifest['default'].blank?
        end
      end

      # Points the UI at `cluster` when it loads.
      def set_default cluster, root: Cli::Helpers.data_root
        update(root) { |manifest| manifest['default'] = cluster }
      end

      def read root: Cli::Helpers.data_root
        file = path(root: root)
        return empty unless File.exist?(file)

        parsed = JSON.parse(File.read(file))
        {
          'default'  => parsed['default'],
          'clusters' => Array(parsed['clusters']).select { |c| c.is_a?(Hash) }
        }
      rescue JSON::ParserError
        # A truncated manifest from an interrupted write shouldn't fail a report.
        empty
      end

      private

      def update root
        manifest = read(root: root)
        yield manifest
        write manifest, root
      end

      def empty
        { 'default' => nil, 'clusters' => [] }
      end

      def write manifest, root
        file = path(root: root)
        FileUtils.mkdir_p File.dirname(file)

        tmp = "#{file}.tmp"
        File.write tmp, manifest.to_json
        File.rename tmp, file
      end

    end
  end
end
