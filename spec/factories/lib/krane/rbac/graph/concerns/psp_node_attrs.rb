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

# This factory will generate expected :Psp graph node attributes

FactoryBot.define do
  factory :psp_node_attrs, class: Hash do

    transient do
      name                       { 'psp-name' }
      privileged                 { false }
      allow_privilege_escalation { false }
      host_network               { false }
      host_ipc                   { false }
      host_ipd                   { false }
      run_as_user                { 'MustRunAsNonRoot' }
      se_linux                   { 'RunAsAny' }
      supplemental_groups        { 'RunAsAny' }
      fs_group                   { 'RunAsAny' }
      allowed_capabilities       { ['NET_ADMIN','IPC_LOCK'] }
      required_drop_capabilities { ['SETUID', 'SETGID'] }
      volumes                    { ['configMap', 'hostPath','secret'] }
      resource_version           { '271831670' }
      creation_timestamp         { '2017-09-29T16:21:33Z' }
    end

    trait :privileged do
      transient do
        privileged { true }
      end
    end

    trait :with_host_network do
      transient do
        host_network { true }
      end
    end
 
    skip_create
    initialize_with do
      {
        name:                     name,
        privileged:               privileged,
        allowPrivilegeEscalation: allow_privilege_escalation,
        allowedCapabilities:      allowed_capabilities,
        requiredDropCapabilities: required_drop_capabilities,
        volumes:                  volumes,
        hostNetwork:              host_network,
        hostIPC:                  host_ipc,
        hostIPD:                  host_ipd, 
        runAsUser:                { rule: run_as_user },
        seLinux:                  { rule: se_linux },
        supplementalGroups:       { rule: supplemental_groups },
        fsGroup:                  { rule: fs_group },
        version:                  resource_version,
        created_at:               creation_timestamp
      }.with_indifferent_access
    end
  end
end
