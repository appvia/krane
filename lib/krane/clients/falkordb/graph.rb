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

# Understands how to run Cypher against a single named graph in FalkorDB

module Krane
  module Clients
    module FalkorDB
      class Graph

        class Error < RuntimeError; end
        class QueryError < Error; end
        class DeleteError < Error; end

        def initialize name, redis_options = {}
          @name  = name
          @redis = Redis.new(redis_options)
        end

        # Runs a Cypher query and decodes the compact result set.
        #
        # @return [QueryResult]
        def query cypher
          QueryResult.new @redis.call('GRAPH.QUERY', @name, cypher, '--compact'), graph: self
        rescue Redis::CommandError => e
          raise QueryError, e.message
        end

        # Removes the graph and every key backing it.
        def delete
          @redis.call('GRAPH.DELETE', @name)
        rescue Redis::CommandError => e
          raise DeleteError, e.message
        end

        # Property names, positionally indexed the way the compact protocol
        # refers to them. Cached, and re-read when a query mentions a property
        # the cache predates.
        #
        # @return [Array<String>]
        def property_keys
          @property_keys ||= @redis.call('GRAPH.QUERY', @name, 'CALL db.propertyKeys()')[1].flatten
        end

        def invalidate_property_keys
          @property_keys = nil
        end

      end
    end
  end
end
