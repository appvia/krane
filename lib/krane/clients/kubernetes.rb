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

# Undestands how to build a Kubernetes Client

require 'kubeclient'
require 'memoist'

module Krane
  module Clients
    class Kubernetes
      extend Memoist

      API_ENDPOINT    = 'https://kubernetes.default.svc' 
      TOKEN_FILE_PATH = '/var/run/secrets/kubernetes.io/serviceaccount/token'
      CA_FILE_PATH    = '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'

      def initialize options
        @options = options

        if @options.incluster # InCluster client
          @api_endpoint = API_ENDPOINT
          @auth_options = { bearer_token_file: TOKEN_FILE_PATH }
          @ssl_options  = File.exist?(CA_FILE_PATH) ? {ca_file: CA_FILE_PATH} : {}
        else           
          # Use KUBECONFIG path if set in environment, 
          # then fall back to default path '~/.kube/config' in current user home directory.
          config = Kubeclient::Config.read(ENV['KUBECONFIG'] || File.expand_path('~/.kube/config'))

          # Use `kubecontext`if provided, otherwise use `current-context`.
          context = @options.kubecontext ? config.context(@options.kubecontext) : config.context

          @api_endpoint = context.api_endpoint
          @auth_options = context.auth_options
          @ssl_options  = context.ssl_options
        end
      end

      memoize def psp
        Kubeclient::Client.new(
          @api_endpoint + '/apis/policy', 'v1beta1',
          auth_options: @auth_options,
          ssl_options:  @ssl_options
        )
      end

      memoize def rbac
        Kubeclient::Client.new(
          @api_endpoint + '/apis/rbac.authorization.k8s.io', 'v1',
          auth_options: @auth_options,
          ssl_options:  @ssl_options
        )
      end
    end
  end
end
