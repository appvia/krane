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

require 'krane/helpers'

require 'krane/clients/kubernetes'
require 'krane/clients/redis_graph'

require 'krane/config/risk'
require 'krane/config/whitelist'

require 'krane/notifications/slack'

require 'krane/rbac/ingest'
require 'krane/rbac/graph/node'
require 'krane/rbac/graph/edge'
require 'krane/rbac/graph/concerns'
require 'krane/rbac/graph/builder'

require 'krane/report/risk_rule/query/rule_selector'
require 'krane/report/risk_rule/query/builder'
require 'krane/report/risk_rule/query/template'
require 'krane/report/risk_rule/item'
require 'krane/report/risk_rule/resolver'
require 'krane/report/element'
require 'krane/report/builder'

require 'krane/visualisations/network_view/builder'
require 'krane/visualisations/tree_view/facet_builder'
require 'krane/visualisations/tree_view/element'
require 'krane/visualisations/tree_view/builder'

require 'krane/extensions'
require 'krane/hacks'
require 'krane/version'
