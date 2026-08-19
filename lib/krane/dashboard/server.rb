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

require 'webrick'

# Understands how to serve the built dashboard as static files.
#
# The dashboard is a static site: the report writes JSON to disk and the browser
# fetches it. Serving it from Ruby keeps node out of the runtime image and means
# the dashboard command no longer shells out.
module Krane
  module Dashboard
    class Server

      DEFAULT_PORT = 8000

      # Defaults to all interfaces because in-cluster the dashboard is reached
      # through a Service. Bind to 127.0.0.1 when running locally.
      DEFAULT_BIND = '0.0.0.0'

      # The build emits no inline scripts and references no external origin, so
      # 'self' covers everything. Styles need 'unsafe-inline' because the graph
      # library sets element styles directly.
      SECURITY_HEADERS = {
        'Content-Security-Policy' => "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'",
        'X-Content-Type-Options'  => 'nosniff',
        'X-Frame-Options'         => 'DENY',
        'Referrer-Policy'         => 'no-referrer'
      }.freeze

      # WEBrick's table predates woff2 and still calls JavaScript application/x-javascript.
      CONTENT_TYPES = {
        '.css'   => 'text/css; charset=utf-8',
        '.html'  => 'text/html; charset=utf-8',
        '.js'    => 'text/javascript; charset=utf-8',
        '.json'  => 'application/json; charset=utf-8',
        '.map'   => 'application/json; charset=utf-8',
        '.png'   => 'image/png',
        '.svg'   => 'image/svg+xml',
        '.woff2' => 'font/woff2',
        '.yaml'  => 'text/yaml; charset=utf-8'
      }.freeze

      DEFAULT_CONTENT_TYPE = 'application/octet-stream'

      # Vite fingerprints everything under /assets, so those URLs can never
      # change meaning. Everything else is rewritten in place by the report loop.
      IMMUTABLE_PREFIX = '/assets/'
      IMMUTABLE_CACHE  = 'public, max-age=31536000, immutable'
      REVALIDATE_CACHE = 'no-cache'

      # @param root [String] directory to serve
      # @param port [Integer] port to listen on
      # @param bind [String] address to bind to
      # @param verbose [Boolean] log each request
      def initialize root:, port: DEFAULT_PORT, bind: DEFAULT_BIND, verbose: false
        @root    = File.realpath(root)
        @port    = port
        @bind    = bind
        @verbose = verbose
      rescue Errno::ENOENT
        raise "Dashboard has not been built: #{root} does not exist"
      end

      # Serves until interrupted.
      #
      # @return [nil]
      def start
        server = build_server
        trap('INT')  { server.shutdown }
        trap('TERM') { server.shutdown }
        server.start
      end

      # Starts serving in a background thread and returns the port in use.
      # Passing port 0 picks a free one, which is what the specs run against.
      #
      # @return [Integer]
      def start_in_background
        @background = build_server
        Thread.new { @background.start }
        @background.listeners.first.addr[1]
      end

      # @return [nil]
      def shutdown
        @background&.shutdown
      end

      private

      def build_server
        WEBrick::HTTPServer.new(
          Port:         @port,
          BindAddress:  @bind,
          AccessLog:    @verbose ? nil : [],
          Logger:       WEBrick::Log.new(@verbose ? $stderr : File::NULL)
        ).tap do |server|
          server.mount_proc('/') { |request, response| serve request, response }
        end
      end

      def serve request, response
        SECURITY_HEADERS.each { |header, value| response[header] = value }

        path = resolve(request.path)
        return not_found(response) if path.nil?

        response['Cache-Control'] = cache_control(request.path)
        response['Content-Type']  = CONTENT_TYPES.fetch(File.extname(path).downcase, DEFAULT_CONTENT_TYPE)

        # The report loop rewrites data files in place, so let the browser
        # revalidate cheaply rather than refetch a chunk it already holds.
        etag = etag_for(path)
        response['ETag'] = etag
        return not_modified(response) if request['If-None-Match'] == etag

        response.status = 200
        response.body = File.open(path, 'rb')
      rescue SystemCallError
        # The file existed a moment ago and does not now: a report regenerated
        # underneath this request and pruned it. That is a 404, not a failure.
        # Reopening is safe once the handle is held, so only the stat and the
        # open can lose this race.
        not_found response
      end

      # Maps a request path to a file inside the docroot, or nil if it does not
      # resolve to one. Resolving through realpath means neither `..` nor a
      # symlink pointing outside the docroot can escape it.
      def resolve request_path
        candidate = File.expand_path(File.join(@root, request_path))
        candidate = File.join(candidate, 'index.html') if File.directory?(candidate)
        return nil unless File.file?(candidate)

        real = File.realpath(candidate)
        contained?(real) ? real : nil
      rescue ArgumentError, SystemCallError
        # null bytes, unreadable paths, broken symlinks
        nil
      end

      def contained? path
        path.start_with? "#{@root}#{File::SEPARATOR}"
      end

      def cache_control request_path
        request_path.start_with?(IMMUTABLE_PREFIX) ? IMMUTABLE_CACHE : REVALIDATE_CACHE
      end

      def etag_for path
        stat = File.stat(path)
        %("#{stat.mtime.to_i.to_s(16)}-#{stat.size.to_s(16)}")
      end

      def not_found response
        response.status = 404
        response['Content-Type'] = CONTENT_TYPES['.json']
        response['Cache-Control'] = REVALIDATE_CACHE
        response.body = { error: 'not found' }.to_json
      end

      def not_modified response
        response.status = 304
        response.body = ''
      end

    end
  end
end
