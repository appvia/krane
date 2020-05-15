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

# Understands how to build RBAC tree view facet element

# Usage:

# require 'docile'

# def facet(obj, &block)
#   Docile.dsl_eval(Krane::Visualisations::TreeView::FacetBuilder.new(facet: obj), &block)
# end

# obj = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

# f = facet(obj) do
#   add tag: :Tag, text: 'Foo', resource_kind: :NAMESPACE
#   add tag: :OtherTag, text: 'Bar'
#   add text: 'Baz'
# end

module Krane
  module Visualisations
    module TreeView
      class FacetBuilder
        include Helpers

        attr_reader :facet

        def initialize facet:
          @facet = facet
          @prev = nil
        end

        def add(tag: nil, text:, resource_kind: nil)
          dimension = {
            tag:           tag, 
            text:          text, 
            resource_kind: resource_kind
          }
          @prev = @prev.nil? ? @facet[dimension] : @prev[dimension]
        end
        
      end
    end
  end
end
