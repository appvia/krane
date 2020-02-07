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

# Understands how to process PodSecurityPolicies

require 'active_support/concern'

module Krane
  module Rbac
    module Graph
      module Concerns
        module PodSecurityPolicies
          extend ActiveSupport::Concern

          included do

            # Iterates through cluster PodSecurityPolicies and adds PSP node to the graph node buffer
            #
            # @return [nil]
            def psp
              iterate :psp do |i|
                psp_name   = i['metadata']['name']
                spec       = i['spec']

                info "-- Indexing [#{i['kind']}] #{psp_name}"

                attrs = {
                  name:                     psp_name,
                  privileged:               spec['privileged'] || false,
                  allowPrivilegeEscalation: spec['allowPrivilegeEscalation'] || false,
                  allowedCapabilities:      spec['allowedCapabilities'].to_a.join(','),
                  volumes:                  spec['volumes'].to_a.join(','),
                  hostNetwork:              spec['hostNetwork'],
                  hostIPC:                  spec['hostIPC'],
                  hostIPD:                  spec['hostIPD'], 
                  runAsUser:                spec['runAsUser']['rule'],
                  seLinux:                  spec['seLinux']['rule'],
                  supplementalGroups:       spec['supplementalGroups']['rule'],
                  fsGroup:                  spec['fsGroup']['rule'],
                  version:                  i['metadata']['resourceVersion'],
                  created_at:               i['metadata']['creationTimestamp']
                }

                node :psp, attrs: attrs
              end
            end

          end # end included
          
        end        
      end
    end
  end
end
