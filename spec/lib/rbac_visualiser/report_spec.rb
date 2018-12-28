RSpec.describe 'RbacVisualiser::Report' do

  describe '#new' do
    context 'with missing cluster name' do
      it 'should raise an exception' do
        expect { RbacVisualiser::Report.new({}) }.to raise_exception KeyError, "key not found: :cluster"
      end
    end

    context 'with cluster name specified' do
      let(:cluster_name) { 'test' }

      it 'should ingest RBAC and build tree data for dashboard' do
        allow(RbacVisualiser::Graph).to receive(:instance).with(cluster: cluster_name) 
        expect_any_instance_of(RbacVisualiser::Ingest).to receive(:run) { double }
        expect_any_instance_of(RbacVisualiser::Tree).to receive(:build) { double }

        RbacVisualiser::Report.new(cluster: cluster_name)
      end
    end
  end

  describe '#run' do
    let(:cluster_name) { 'test' }

    subject(:subject) do
      allow(RbacVisualiser::Graph).to receive(:instance).with(cluster: cluster_name)
      expect_any_instance_of(RbacVisualiser::Ingest).to receive(:run) { double }
      expect_any_instance_of(RbacVisualiser::Tree).to receive(:build) { double }

      RbacVisualiser::Report.new(cluster: cluster_name)
    end

    before :each do
      allow(subject).to receive(:ingest_time_findings)
      allow(subject).to receive(:finding)
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:write)
    end

    after :each do
      subject.run
    end

    it 'should compile ingest-time findings' do
      expect(subject).to receive(:ingest_time_findings)
    end

    it 'should iterate the rules config items and run findings report for each' do  
      expect(subject).to receive(:finding).with(anything).exactly(8).times
    end
  end

  describe 'private methods' do
    let(:cluster_name) { 'test' }
    let(:graph) { double }

    subject(:subject) do
      allow(RbacVisualiser::Graph).to receive(:instance).with(cluster: cluster_name) { graph }
      expect_any_instance_of(RbacVisualiser::Ingest).to receive(:run) { double }
      expect_any_instance_of(RbacVisualiser::Tree).to receive(:build) { double }

      RbacVisualiser::Report.new(cluster: cluster_name)
    end

    describe '#finding' do
      let(:writer_function) { double }
      let(:writer_fn_eval_results) { double }
      let(:item) do
        {
          severity: :info,
          group_title: 'some title',
          info: 'more detailed info',
          query: 'complex graph query goes here',
          writer: writer_function
        }
      end

      it 'compiles report elements' do
        res = double
        allow(graph).to receive(:query) { res }
        allow(graph).to receive(:delete)

        expect(RbacVisualiser::ReportElement).to receive(:get).with(
          severity: item[:severity],
          group_title: item[:group_title],
          info: item[:info],
          data: res,
          writer: anything
        )

        subject.send(:finding, item)
      end
    end

  end

end
