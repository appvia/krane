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
  factory :edge, class: Krane::Rbac::Graph::Edge do

    source_label        { 'source-node-label' }
    relation            { :ACCESS }
    destination_label   { 'dest-node-label'}
    direction           { '<->' }

    trait :invalid do
      unknown_property { "unknown_value" }
    end

    trait :access do
      relation { :ACCESS }
    end

    trait :assign do
      relation { :ASSIGN }
    end

    trait :aggregate do
      relation { :AGGREGATE }
    end

    trait :composite do
      relation { :COMPOSITE }
    end

    trait :security do
      relation { :SECURITY }
    end

    trait :grant do
      relation { :GRANT }
    end

    trait :relation do
      relation { :RELATION }
    end

    trait :scope do
      relation { :SCOPE }
    end
 
    skip_create
    initialize_with { new(attributes) }
  end
end
