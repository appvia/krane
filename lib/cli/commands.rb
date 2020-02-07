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

# Understands CLI Commands implementation

module Cli
  module Commands
    extend self

    def report options
      report = Krane::Report::Builder.new(options).build

      if options.ci
        unless report.dangers.empty?
          say "[CI] RBAC test failed. #{report.dangers.size} checks didn't pass...".red
          say JSON.pretty_generate(report.dangers)
          exit 1
        end
        say "[CI] RBAC test passed...".green
      else
        case options.output.to_sym
        when :yaml
          say report.combined.to_yaml
        when :json
          say JSON.pretty_generate(report.combined)
        end
      end

    end

    def dashboard options
      say "---".light_cyan
      say "KRANE DASHBOARD:".light_cyan
      say "http://localhost:#{options.port}".light_cyan
      say "---".light_cyan

      %x(port=#{options.port} path=./dashboard/compiled node dashboard/dashboard.js)
    end

  end
end
