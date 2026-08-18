require 'spec_helper'
require 'tmpdir'

describe Krane::Visualisations::TreeView::Writer do

  around(:each) do |example|
    Dir.mktmpdir { |dir| @root = File.join(dir, 'tree'); example.run }
  end

  # A tree shaped like the builder's output: root -> facet wrappers -> nodes that
  # become chunks -> everything below, which travels inside the chunk.
  def tree with_facets: nil
    {
      text: 'test cluster',
      nodes: with_facets || [
        {
          facet: :namespaces,
          text: 'Namespaces',
          nodes: [
            {
              branch: :NAMESPACE, text: 'kube-system', tags: ['Namespace'], navigable: true,
              nodes: [
                { branch: :NAMESPACE, text: 'ServiceAccount', tags: ['admits'], navigable: true,
                  nodes: [{ branch: :NAMESPACE, text: 'coredns', tags: ['ServiceAccount'], navigable: false }] }
              ]
            },
            { branch: :NAMESPACE, text: 'kube-public', tags: ['Namespace'], navigable: true }
          ]
        },
        {
          facet: :roles,
          text: 'Roles',
          nodes: [
            { branch: :ROLE, text: 'ClusterRole', tags: [''], navigable: true,
              nodes: [{ branch: :ROLE, text: 'cluster-admin', tags: ['ClusterRole'], navigable: true }] }
          ]
        }
      ]
    }
  end

  def write tree_data = tree
    described_class.new(cluster: 'test', tree: tree_data, root: @root).write
  end

  def read_json relative_path
    JSON.parse File.read(File.join(@root, relative_path))
  end

  def files_written
    Dir.glob(File.join(@root, '**', '*')).reject { |p| File.directory?(p) }
        .map { |p| p.sub("#{@root}/", '') }.sort
  end

  describe '#write' do

    describe 'layout' do

      it 'writes an index, a search index, a manifest and one chunk per truncated node' do
        write

        # kube-public has no children, so it stays a leaf in the index and gets no chunk
        expect(files_written).to eq [
          'index.json',
          'manifest.json',
          'namespaces/kube-system.json',
          'roles/clusterrole.json',
          'search.json'
        ]
      end

      it 'writes chunks into a directory named after the facet' do
        write
        expect(read_json('index.json')['nodes'][0]['facet']).to eq 'namespaces'
        expect(read_json('index.json')['nodes'][0]['nodes'][0]['chunk']).to eq 'namespaces/kube-system.json'
      end

      it 'leaves no temporary files behind' do
        write
        expect(files_written.grep(/\.tmp\z/)).to be_empty
      end

      it 'stamps the manifest with a format version and a generation time' do
        write
        manifest = read_json('manifest.json')

        expect(manifest['format_version']).to eq described_class::FORMAT_VERSION
        expect(Time.parse(manifest['generated_at'])).to be_within(60).of(Time.now)
      end

    end

    describe 'index' do

      it 'keeps nodes above the chunk depth inline' do
        index = (write; read_json('index.json'))

        expect(index['text']).to eq 'test cluster'
        expect(index['nodes'].map { |n| n['text'] }).to eq ['Namespaces', 'Roles']
      end

      it 'replaces the children of a truncated node with a reference to its chunk' do
        write
        node = read_json('index.json')['nodes'][0]['nodes'][0]

        expect(node).not_to have_key 'nodes'
        expect(node['chunk']).to eq 'namespaces/kube-system.json'
        expect(node['node_count']).to eq 2 # ServiceAccount + coredns
      end

      it 'preserves the display attributes of a truncated node' do
        write
        node = read_json('index.json')['nodes'][0]['nodes'][0]

        expect(node).to include('branch' => 'NAMESPACE', 'text' => 'kube-system',
                                'tags' => ['Namespace'], 'navigable' => true)
      end

      it 'does not give a childless node a chunk' do
        write
        node = read_json('index.json')['nodes'][0]['nodes'][1]

        expect(node['text']).to eq 'kube-public'
        expect(node).not_to have_key 'chunk'
        expect(node).not_to have_key 'nodes'
      end

    end

    describe 'chunks' do

      it 'holds the children of the node it was split from' do
        write
        chunk = read_json('namespaces/kube-system.json')

        expect(chunk['nodes'].map { |n| n['text'] }).to eq ['ServiceAccount']
        expect(chunk['nodes'][0]['nodes'].map { |n| n['text'] }).to eq ['coredns']
      end

      it 'is reachable from every chunk reference in the index' do
        write
        index = read_json('index.json')

        chunks = index['nodes'].flat_map { |facet| facet['nodes'] }
                               .filter_map { |node| node['chunk'] }

        expect(chunks).not_to be_empty
        chunks.each { |chunk| expect(File.exist?(File.join(@root, chunk))).to be true }
      end

      it 'suffixes a slug that another node in the same facet already claimed' do
        write tree(with_facets: [{
          facet: :resources,
          text: 'Resource Access',
          nodes: [
            { text: '[core] pods', nodes: [{ text: 'get' }] },
            { text: 'core pods',   nodes: [{ text: 'list' }] }
          ]
        }])

        expect(files_written).to include 'resources/core-pods.json', 'resources/core-pods-2.json'
      end

    end

    describe 'search index' do

      it 'lists the index itself as the first searchable chunk' do
        write
        expect(read_json('search.json')['chunks'].first).to eq 'index.json'
      end

      it 'maps a term to every chunk containing it' do
        write
        search = read_json('search.json')

        # 'ClusterRole' is the text of an index level node and a tag deep inside a chunk
        expect(search['chunks'][search['terms']['cluster-admin'].first]).to eq 'roles/clusterrole.json'
        expect(search['terms']['namespaces']).to eq [0]
      end

      it 'records a term against a chunk only once' do
        write
        read_json('search.json')['terms'].each_value do |chunks|
          expect(chunks).to eq chunks.uniq
        end
      end

    end

    describe 'regenerating over a previous run' do

      it 'removes chunks the new index no longer refers to' do
        write
        expect(files_written).to include 'namespaces/kube-system.json'

        write tree(with_facets: [{ facet: :roles, text: 'Roles',
                                   nodes: [{ text: 'Role', nodes: [{ text: 'reader' }] }] }])

        expect(files_written).to eq ['index.json', 'manifest.json', 'roles/role.json', 'search.json']
      end

      it 'removes a facet directory that no longer has any chunks' do
        write
        write tree(with_facets: [{ facet: :roles, text: 'Roles',
                                   nodes: [{ text: 'Role', nodes: [{ text: 'reader' }] }] }])

        expect(Dir.exist?(File.join(@root, 'namespaces'))).to be false
      end

      it 'writes the manifest last, so it never points at chunks that are not on disk yet' do
        renamed = []
        allow(File).to receive(:rename).and_wrap_original do |original, tmp, target|
          renamed << target.sub("#{@root}/", '')
          original.call tmp, target
        end

        write

        expect(renamed.last).to eq 'manifest.json'
        expect(renamed.index('index.json')).to be > renamed.index('namespaces/kube-system.json')
      end

      it 'keeps the previous manifest in place until the new one replaces it' do
        write
        first = read_json('manifest.json')

        allow(File).to receive(:rename).and_wrap_original do |original, tmp, target|
          # by the time anything else is written, the old manifest must still be readable
          expect(read_json('manifest.json')).to eq first unless target.end_with?('manifest.json')
          original.call tmp, target
        end

        write
      end

    end

  end

end
