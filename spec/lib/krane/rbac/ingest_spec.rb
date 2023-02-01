RSpec.describe Krane::Rbac::Ingest do

  let(:graph_client) { double }

  before do
    allow_any_instance_of(described_class).to receive(:get_graph_client) { graph_client }
  end

  describe '#new' do

    context 'with missing cluster name options' do

      let(:options) { OpenStruct.new(cluster: nil) } # unset default value for test
      subject { described_class.new(options) }

      it 'should raise an exception' do
        expect { subject }.to raise_exception "Cluster name must be specified in params"
      end

    end

    context 'with --noindex option' do

      let(:options) { OpenStruct.new(cluster: 'default', noindex: noindex) } # mock options

      context 'present' do

        let(:noindex) { true }

        it 'should not attempt to delete rbac graph for given cluster' do
          expect(graph_client).to receive(:delete).never
          described_class.new(options)
        end

      end

      context 'not present' do

        let(:noindex) { false }

        it 'should attempt to delete rbac graph for given cluster' do
          expect(graph_client).to receive(:delete).once
          described_class.new(options)
        end

      end

    end

  end

  describe '#run' do

    let(:options) { OpenStruct.new(cluster: :default, noindex: noindex) } # mock options

    before do
      allow(graph_client).to receive(:delete)
    end

    context 'with --noindex option present (indexing disabled)' do

      let(:noindex) { true }

      it 'will only cache rbac locally and return nil - no further processing' do
        expect_any_instance_of(described_class).to receive(:cache_rbac).once
        expect_any_instance_of(described_class).to receive(:index_rbac).never
        expect(described_class.new(options).run).to be_nil
      end

    end

    context 'without --noindex option' do

      let(:noindex) { false }

      it 'will cache and index rbac in the graph' do
        expect_any_instance_of(described_class).to receive(:cache_rbac).once
        expect_any_instance_of(described_class).to receive(:index_rbac).once
        described_class.new(options).run
      end

    end

  end

  describe 'private methods' do

    before do
      allow(graph_client).to receive(:delete)
    end

    describe '#cache_rbac' do

      let(:options) do
        OpenStruct.new(
          cluster: :default, 
          incluster: incluster, 
          kubecontext: kubecontext, 
          dir: dir
        )
      end # mock options

      context 'with --incluster option present' do

        let(:incluster)   { true }
        let(:kubecontext) { nil }
        let(:dir)         { nil }

        it 'will fetch rbac from within the runing cluster' do
          instance = described_class.new(options)
          expect(instance).to receive(:fetch_rbac)
          instance.send(:cache_rbac)
        end

      end

      context 'with --kubeconfig option present' do

        let(:incluster)   { false }
        let(:kubecontext) { 'some-context' }
        let(:dir)         { nil }

        it 'will fetch rbac using kubecontext' do
          instance = described_class.new(options)
          expect(instance).to receive(:fetch_rbac)
          instance.send(:cache_rbac)
        end

      end

      context 'with --dir option present' do

        let(:incluster)   { false }
        let(:kubecontext) { nil }
        let(:dir)         { '/some/dir/path' }

        it 'will set cache path to value provided via --dir option' do
          instance = described_class.new(options)
          instance.send(:cache_rbac)
          expect(instance.instance_variable_get(:@cache_path)).to eq dir
        end

      end

    end

    describe '#index_rbac' do

      let(:build_graph_results) do 
        double( :graph, 
          body: 'graph body...',
          undefined_roles: ['set of undefined roles'],
          unused_roles: ['set of unused roles'],
          bindings_without_subject: ['set of bindings without subject'],
          network_nodes: ['set of network graph nodes'],
          network_edges: ['set of network graph edges']
        )
      end
      let(:dir) { '/some/rbac/cache/dir' }
      let(:options) do
        OpenStruct.new(
          cluster: :default, 
          dir:     dir
        )
      end # mock options
      let(:k8s_client) { double }

      before do
        @instance = described_class.new(options)
        @instance.instance_variable_set(:@cache_path, dir)

        allow(Krane::Clients::Kubernetes).to receive(:new).with(options) { k8s_client }
        allow(k8s_client).to receive(:version) { 1.23 }
      end

      it 'will build and index rbac graph, and return a results map' do
        expect(@instance).to receive(:build_graph).with(dir) { build_graph_results }

        expect(graph_client).to receive(:query).with(%Q(CREATE #{build_graph_results.body}))
        expect(graph_client).to receive(:query).with(%Q(CREATE INDEX ON :Namespace(name)))
        expect(graph_client).to receive(:query).with(%Q(CREATE INDEX ON :Subject(name)))
        expect(graph_client).to receive(:query).with(%Q(CREATE INDEX ON :Role(name)))
        expect(graph_client).to receive(:query).with(%Q(CREATE INDEX ON :Rule(name)))

        map = @instance.send(:index_rbac)

        expect(map).to include(
          undefined_roles:          build_graph_results.undefined_roles,
          unused_roles:             build_graph_results.unused_roles,
          bindings_without_subject: build_graph_results.bindings_without_subject,
          rbac_graph_network_nodes: build_graph_results.network_nodes,
          rbac_graph_network_edges: build_graph_results.network_edges
        )
      end

    end

    describe '#fetch_rbac' do

      let(:psps) { double }
      let(:roles) { double }
      let(:role_bindings) { double }
      let(:cluster_roles) { double }
      let(:cluster_role_bindings) { double }

      let(:k8s_client) { double }

      let(:dir) { '/some/rbac/cache/dir' }
      let(:options) do
        OpenStruct.new(
          cluster: :default, 
          dir:     dir
        )
      end # mock options

      before do
        @instance = described_class.new(options)
        @instance.instance_variable_set(:@cache_path, dir)

        allow(k8s_client).to receive_message_chain(:psp, :get_pod_security_policies).with(as: :raw) { psps }
        allow(k8s_client).to receive_message_chain(:rbac, :get_roles).with(as: :raw) { roles }
        allow(k8s_client).to receive_message_chain(:rbac, :get_role_bindings).with(as: :raw) { role_bindings }
        allow(k8s_client).to receive_message_chain(:rbac, :get_cluster_roles).with(as: :raw) { cluster_roles }
        allow(k8s_client).to receive_message_chain(:rbac, :get_cluster_role_bindings).with(as: :raw) { cluster_role_bindings }
        allow(Krane::Clients::Kubernetes).to receive(:new).with(options) { k8s_client }
      end


      context 'for k8s version < 1.25' do

        before do
          allow(k8s_client).to receive(:version) { 1.23 }
          allow(k8s_client).to receive_message_chain(:psp, :get_pod_security_policies).with(as: :raw) { psps }
        end

        it 'will call Kubernetes API and fetch RBAC objects including PSPs and cache them locally' do
          expect(FileUtils).to receive(:mkdir_p).with(dir)
          expect(File).to receive(:write).with("#{dir}/psp", psps)
          expect(File).to receive(:write).with("#{dir}/roles", roles)
          expect(File).to receive(:write).with("#{dir}/rolebindings", role_bindings)
          expect(File).to receive(:write).with("#{dir}/clusterroles", cluster_roles)
          expect(File).to receive(:write).with("#{dir}/clusterrolebindings", cluster_role_bindings)

          @instance.send(:fetch_rbac)
        end

      end


      context 'for k8s version >= 1.25' do

        before do
          allow(k8s_client).to receive(:version) { 1.25 }
        end

        it 'will call Kubernetes API and fetch RBAC objects excluding deprecated PSPs and cache them locally' do
          expect(FileUtils).to receive(:mkdir_p).with(dir)
          expect(File).to_not receive(:write).with("#{dir}/psp", psps)
          expect(File).to receive(:write).with("#{dir}/roles", roles)
          expect(File).to receive(:write).with("#{dir}/rolebindings", role_bindings)
          expect(File).to receive(:write).with("#{dir}/clusterroles", cluster_roles)
          expect(File).to receive(:write).with("#{dir}/clusterrolebindings", cluster_role_bindings)

          @instance.send(:fetch_rbac)
        end

      end

    end

  end

end
