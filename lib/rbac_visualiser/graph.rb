require 'redis'

module RbacVisualiser
  module Graph
    extend self

    HOST = "127.0.0.1"
    PORT = 6666

    def instance attrs
      cluster = attrs.fetch(:cluster) { raise 'Cluster name not specified' }
      host = attrs.fetch(:host, HOST)
      port = attrs.fetch(:port, PORT)
      ::RedisGraph.new("rbac-#{cluster}", { host: host, port: port })
    end
  end
end
