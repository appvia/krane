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

# Common methods

module Krane
  module Helpers

    def get_cluster_slug
      raise "Cluster name must be specified in params" if @options.cluster.blank?
      @options.cluster.to_s.downcase.strip.gsub(/\W/,'-')
    end

    def get_graph_client
      Krane::Clients::RedisGraph.client cluster: get_cluster_slug
    end

    def banner prefix, txt
      say "#{prefix.upcase}: #{txt}".yellow.on_blue unless test?
    end

    def info txt, colour = :light_blue
      say txt.send(colour) if @options.verbose && !test?
    end

    def test?
      ENV['KRANE_ENV'] == 'test'
    end

    def load_config_yaml file
      path = File.expand_path(File.join(File.dirname(__FILE__), '../../', "config/#{file}"))
      YAML.load_file(path).with_indifferent_access if File.exist?(path)
    end

  end
end
