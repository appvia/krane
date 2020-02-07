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

FactoryBot.define do
  factory :kubernetes, class: Krane::Clients::Kubernetes do

    trait :incluster do
      options do 
        OpenStruct.new(incluster: true) # emulate commandline options
      end
    end

    trait :with_kubecontext do
      options do 
        OpenStruct.new(kubecontext: 'minikube') # emulate commandline options
      end
    end

    after(:build) do |k| 
      k.instance_variable_set(:@api_endpoint, 'https://some-endpoint')
      k.instance_variable_set(:@auth_options, { bearer_token: 'xxxxx' })
      k.instance_variable_set(:@api_endpoint, { verify_ssl: 1 })
    end

    skip_create
    initialize_with { new(options) }
  end
end
