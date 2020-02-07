RSpec.describe Krane::Report::Builder do

  describe '#build' do

    let(:cluster) { 'some-cluster' }
    let(:options) { OpenStruct.new(cluster: cluster) }
    subject { described_class.new(options) }

    before do
      # don't instantiate RedisGraph client
      allow(Krane::Clients::RedisGraph).to receive(:client).with(anything) { double }
      # don't process any risk rule - return empty set
      allow(Krane::Report::RiskRule::Resolver).to receive(:new).with(
        cluster:   cluster, 
        risk:      anything,
        whitelist: anything
      ) { OpenStruct.new(risk_rules: []) }
    end

    context 'for non-CI execution' do

      it 'will ingest RBAC, build network & tree views, produce ingest time findings and run hooks' do
        expect(subject).to receive(:ingest_rbac) { {} }
        expect(subject).to receive(:build_rbac_network_view)
        expect(subject).to receive(:build_rbac_tree_view)
        expect(subject).to receive(:ingest_time_findings)
        expect(subject).to receive(:sort_findings)
        expect(subject).to receive(:run_hooks)
        subject.build
      end
    
    end

    context 'for CI execution' do

      let(:options) { OpenStruct.new(cluster: 'some-cluster', ci: true) }

      it 'will ingest RBAC and produce ingest time findings only' do
        expect(subject).to receive(:ingest_rbac)
        expect(subject).to receive(:ingest_time_findings)
        expect(subject).to receive(:sort_findings)
        expect(subject).to receive(:build_rbac_network_view).never
        expect(subject).to receive(:build_rbac_tree_view).never
        expect(subject).to receive(:run_hooks).never
        subject.build
      end

    end

  end

end
