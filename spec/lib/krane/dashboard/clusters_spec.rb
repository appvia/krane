require 'spec_helper'
require 'tmpdir'

describe Krane::Dashboard::Clusters do

  around(:each) do |example|
    Dir.mktmpdir { |dir| @root = dir; example.run }
  end

  def record cluster
    described_class.record cluster, root: @root
  end

  def manifest
    JSON.parse File.read(File.join(@root, 'clusters.json'))
  end

  describe '.record' do

    it 'adds a cluster with the time its data was generated' do
      record 'production'

      expect(manifest['clusters'].size).to eq 1
      expect(manifest['clusters'][0]['name']).to eq 'production'
      expect(Time.parse(manifest['clusters'][0]['generated_at'])).to be_within(60).of(Time.now)
    end

    it 'makes the first recorded cluster the default' do
      record 'production'
      expect(manifest['default']).to eq 'production'
    end

    it 'does not move the default when another cluster is recorded' do
      record 'production'
      record 'staging'

      expect(manifest['default']).to eq 'production'
    end

    it 'refreshes an existing cluster rather than duplicating it' do
      record 'production'
      first = manifest['clusters'][0]['generated_at']

      travel = Time.now + 120
      allow(Time).to receive(:now).and_return(travel)
      record 'production'

      expect(manifest['clusters'].map { |c| c['name'] }).to eq ['production']
      expect(manifest['clusters'][0]['generated_at']).not_to eq first
    end

    it 'keeps clusters in name order' do
      ['staging', 'production', 'dev'].each { |c| record c }

      expect(manifest['clusters'].map { |c| c['name'] }).to eq ['dev', 'production', 'staging']
    end

    it 'writes atomically, leaving no temporary file behind' do
      record 'production'
      expect(Dir.glob(File.join(@root, '*.tmp'))).to be_empty
    end

  end

  describe '.set_default' do

    it 'points the dashboard at the given cluster' do
      record 'production'
      record 'staging'
      described_class.set_default 'staging', root: @root

      expect(manifest['default']).to eq 'staging'
    end

    it 'records a default for a cluster that has no data yet' do
      described_class.set_default 'staging', root: @root

      expect(manifest['default']).to eq 'staging'
      expect(manifest['clusters']).to be_empty
    end

  end

  describe '.read' do

    it 'returns an empty manifest when none has been written' do
      expect(described_class.read(root: @root)).to eq('default' => nil, 'clusters' => [])
    end

    it 'falls back to an empty manifest rather than raising on a corrupt file' do
      File.write File.join(@root, 'clusters.json'), '{"clusters": [{"name"'

      expect(described_class.read(root: @root)).to eq('default' => nil, 'clusters' => [])
    end

  end

end
