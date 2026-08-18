require 'spec_helper'
require 'tmpdir'
require 'net/http'

describe Krane::Dashboard::Server do

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @root = File.realpath(dir)
      FileUtils.mkdir_p File.join(@root, 'assets')
      FileUtils.mkdir_p File.join(@root, 'data', 'default')

      File.write File.join(@root, 'index.html'), '<!doctype html><title>krane</title>'
      File.write File.join(@root, 'assets', 'app-a1b2c3.js'), 'console.log(1)'
      File.write File.join(@root, 'data', 'clusters.json'), '{"default":"default"}'
      File.write File.join(@root, 'data', 'default', 'rbac-findings.json'), '{}'

      example.run
    end
  end

  before(:each) do
    @server = described_class.new(root: @root, port: 0, bind: '127.0.0.1')
    @port   = @server.start_in_background
  end

  after(:each) { @server.shutdown }

  # Sends `path` verbatim, so the specs can exercise paths a URI helper would
  # otherwise normalise away.
  def get path, headers = {}
    Net::HTTP.start('127.0.0.1', @port) do |http|
      http.request Net::HTTP::Get.new(path, headers)
    end
  end

  describe 'serving files' do

    it 'serves a file from the docroot' do
      response = get '/index.html'

      expect(response.code).to eq '200'
      expect(response.body).to include 'krane'
    end

    it 'serves index.html for the root path' do
      expect(get('/').body).to include 'krane'
    end

    it 'serves report data' do
      expect(get('/data/default/rbac-findings.json').code).to eq '200'
    end

    it 'labels JavaScript as text/javascript rather than the x- prefixed legacy type' do
      expect(get('/assets/app-a1b2c3.js')['content-type']).to eq 'text/javascript; charset=utf-8'
    end

    it 'labels JSON as application/json' do
      expect(get('/data/clusters.json')['content-type']).to eq 'application/json; charset=utf-8'
    end

    it 'returns 404 for a file that is not there' do
      response = get '/data/missing/rbac-findings.json'

      expect(response.code).to eq '404'
      expect(response['content-type']).to eq 'application/json; charset=utf-8'
    end

    it 'returns 404 when a report regenerates the file out from under the request' do
      # The report loop prunes chunks the new index no longer refers to, so a
      # file can pass the existence check and be gone by the time it is read.
      # Verified live against a container: this used to be a 500.
      allow(File).to receive(:stat).and_call_original
      allow(File).to receive(:stat)
        .with(File.join(@root, 'data', 'default', 'rbac-findings.json'))
        .and_raise(Errno::ENOENT)

      expect(get('/data/default/rbac-findings.json').code).to eq '404'
    end

    it 'returns 404 when the file disappears between the stat and the open' do
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open)
        .with(File.join(@root, 'data', 'default', 'rbac-findings.json'), 'rb')
        .and_raise(Errno::ENOENT)

      expect(get('/data/default/rbac-findings.json').code).to eq '404'
    end

  end

  describe 'security headers' do

    it 'confines the page to same origin content' do
      expect(get('/index.html')['content-security-policy'])
        .to eq "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'"
    end

    it 'stops the browser sniffing a content type' do
      expect(get('/index.html')['x-content-type-options']).to eq 'nosniff'
    end

    it 'refuses to be framed' do
      expect(get('/index.html')['x-frame-options']).to eq 'DENY'
    end

    it 'leaks no referrer' do
      expect(get('/index.html')['referrer-policy']).to eq 'no-referrer'
    end

    it 'sets the headers on an error response too' do
      expect(get('/nope')['x-content-type-options']).to eq 'nosniff'
    end

  end

  describe 'path containment' do

    before(:each) do
      @secret = File.join(File.dirname(@root), 'secret.txt')
      File.write @secret, 'top secret'
    end

    after(:each) { FileUtils.rm_f @secret }

    # Traversal is refused twice over: WEBrick rejects a path containing `..`
    # as a bad request, and the handler resolves through realpath before serving
    # anything. These assert the property rather than which layer answered.
    def expect_refused path
      response = get path

      expect(response.code).not_to eq '200'
      expect(response.body.to_s).not_to include 'top secret'
    end

    it 'refuses to walk out of the docroot' do
      expect_refused '/../secret.txt'
    end

    it 'refuses to walk out of the docroot through a nested path' do
      expect_refused '/data/default/../../../secret.txt'
    end

    it 'refuses an escape hidden in percent encoding' do
      expect_refused '/%2e%2e%2fsecret.txt'
    end

    it 'refuses to follow a symlink pointing outside the docroot' do
      File.symlink @secret, File.join(@root, 'leak.txt')

      expect(get('/leak.txt').code).to eq '404'
    end

    it 'serves a symlink that stays inside the docroot' do
      File.symlink File.join(@root, 'index.html'), File.join(@root, 'alias.html')

      expect(get('/alias.html').code).to eq '200'
    end

    it 'does not fall over on a null byte in the path' do
      expect(get('/index.html%00.js').code).to eq '404'
    end

  end

  describe 'caching' do

    it 'lets fingerprinted assets be cached forever' do
      expect(get('/assets/app-a1b2c3.js')['cache-control']).to eq 'public, max-age=31536000, immutable'
    end

    it 'makes the browser revalidate report data, which the report loop rewrites in place' do
      expect(get('/data/clusters.json')['cache-control']).to eq 'no-cache'
    end

    it 'makes the browser revalidate the entry point' do
      expect(get('/index.html')['cache-control']).to eq 'no-cache'
    end

    it 'answers a revalidation of unchanged data with 304' do
      etag = get('/data/default/rbac-findings.json')['etag']
      expect(etag).not_to be_nil

      response = get '/data/default/rbac-findings.json', 'If-None-Match' => etag

      expect(response.code).to eq '304'
    end

    it 'sends the file again once it has changed' do
      etag = get('/data/default/rbac-findings.json')['etag']

      path = File.join(@root, 'data', 'default', 'rbac-findings.json')
      File.write path, '{"summary":{}}'
      FileUtils.touch path, mtime: Time.now + 60

      expect(get('/data/default/rbac-findings.json', 'If-None-Match' => etag).code).to eq '200'
    end

  end

  describe 'startup' do

    it 'fails with a clear message when the dashboard has not been built' do
      expect { described_class.new(root: File.join(@root, 'nope')) }
        .to raise_error(/has not been built/)
    end

  end

end
