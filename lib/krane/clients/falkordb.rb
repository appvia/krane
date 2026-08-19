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

# Understands how to talk to FalkorDB, the graph database krane indexes RBAC into.
#
# FalkorDB continues RedisGraph, which reached end of life, and speaks the same
# GRAPH.* commands over the Redis protocol. The only Ruby client for those
# commands, the `redisgraph` gem, was abandoned along with RedisGraph itself, so
# krane owns the handful of calls it needs instead.

require 'redis'

module Krane
  module Clients
    module FalkorDB
      extend self

      FALKORDB_HOST = "127.0.0.1"
      FALKORDB_PORT = 6379

      def client attrs = {}
        cluster = attrs.fetch(:cluster, 'default')
        host    = attrs.fetch(:host, ENV['FALKORDB_HOST'] || ENV['REDIS_GRAPH_HOST'] || FALKORDB_HOST)
        port    = attrs.fetch(:port, ENV['FALKORDB_PORT'] || ENV['REDIS_GRAPH_PORT'] || FALKORDB_PORT)
        Graph.new("rbac-#{cluster}", { host: host, port: port })
      end
    end
  end
end
