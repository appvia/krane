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

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'krane/version'

Gem::Specification.new do |spec|
  spec.name          = "krane"
  spec.version       = Krane::VERSION
  spec.authors       = ['Marcin Ciszak']
  spec.email         = ['marcin.ciszak@appvia.io']

  spec.summary       = %q{Kubernetes RBAC static analysis & visualisation tool.}

  spec.license       = 'Apache License, Version 2.0'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "to-do: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files         = Dir['LICENSE.txt', 'README.md', 'Dockerfile', 'Gemfile*', 'krane.gemspec', '.ruby-version',
                        'lib/**/*', 'dashboard/**/*', 'config/**/*', 'bin/**/*', 'kube/**/*']

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '>= 2.2.28'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'factory_bot'
  spec.add_development_dependency 'profile'
  spec.add_development_dependency 'ruby-prof'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'rdoc', '>= 6.3.1'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'test-unit'
  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'commander'
  spec.add_runtime_dependency 'colorize'
  spec.add_runtime_dependency 'docile'
  spec.add_runtime_dependency 'facets'
  spec.add_runtime_dependency 'hashie'
  spec.add_runtime_dependency 'jekyll', '~> 4.3'
  spec.add_runtime_dependency 'kubeclient'
  spec.add_runtime_dependency 'memoist'
  spec.add_runtime_dependency 'openid_connect'
  spec.add_runtime_dependency 'redisgraph'
  spec.add_runtime_dependency 'slack-notifier', '~> 2.2', '>= 2.2.2'
end
