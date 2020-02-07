RSpec.describe Krane::Rbac::Graph::Node do

  subject { described_class }

  describe '#new' do

    context 'with correct attributes' do

      subject { build(:node) }

      it 'creates a new Node object' do
        expect { subject }.not_to raise_error
        expect(subject).not_to   be nil
      end

    end

    context 'with invalid / not defined properties' do

      subject { build(:node, :invalid) }

      it 'fails to instantiate a new Node object and throws an exception' do
        expect { subject }.to raise_error(
          NoMethodError, "The property 'unknown_property' is not defined for Krane::Rbac::Graph::Node."
        )
      end

    end

  end

  describe '#to_s' do

    subject { build(:node) }

    it 'returns string representation of the node to be indexed in the graph' do
      expected_attrs = subject.attrs.map {|k,v| "#{k.to_s}:'#{v.to_s}'"}.join(", ")
      expect(subject.to_s).to eq %Q((#{subject.label}:#{subject.kind} {#{expected_attrs}}))
    end

  end

  describe '#to_network' do

    context 'for :Psp node kind' do

      subject { build(:node, :psp) }

      it 'returns nil' do
        expect(subject.to_network).to be_nil
      end

    end

    context 'for :Rule node kind' do

      subject { build(:node, :rule) }

      it 'returns nil' do
        expect(subject.to_network).to be_nil
      end

    end

    context 'for :Role node kind' do

      subject { build(:node, :role) }

      it 'returns a map representation of a given node for use in the network view' do
        map = subject.to_network
        expect(map.keys.size).to eq 5
        expect(map).to include( # group / title tested above
          id:    subject.label,
          label: "#{subject.attrs[:kind]}: #{subject.attrs[:name]}",
          value: nil
        )
      end

      context 'for default role' do

        subject { build(:node, :role, :default) }

        it 'builds network node title correctly' do
          title = subject.to_network[:title]
          expect(title).to include("#{subject.attrs[:kind]}: #{subject.attrs[:name]}")
          expect(title).to include("- Default k8s role")
        end

        it 'builds network node group attribure correctly' do
          group = subject.to_network[:group]
          expect(group).to eq [
            described_class::GRAPH_NETWORK_NODE_GROUP[subject.kind],
            described_class::GRAPH_NETWORK_NODE_GROUP_BOOST[:is_default],
          ].sum
        end

      end

      context 'for composite role' do

        subject { build(:node, :role, :composite) }

        it 'builds network node title correctly' do
          title = subject.to_network[:title]
          expect(title).to include("#{subject.attrs[:kind]}: #{subject.attrs[:name]}")
          expect(title).to include("- Aggregates rules defined in other cluster roles")
        end

        it 'builds network node group attribure correctly' do
          group = subject.to_network[:group]
          expect(group).to eq [
            described_class::GRAPH_NETWORK_NODE_GROUP[subject.kind],
            described_class::GRAPH_NETWORK_NODE_GROUP_BOOST[:is_composite],
          ].sum
        end

      end

      context 'for aggregable role' do

        subject { build(:node, :role, :aggregable, :aggregable_by_roles) }

        it 'builds network node title correctly' do
          title = subject.to_network[:title]
          expect(title).to include("#{subject.attrs[:kind]}: #{subject.attrs[:name]}")
          expect(title).to include("- Can be aggregated by cluster roles: #{subject.attrs[:aggregable_by]}")
        end

        it 'builds network node group attribure correctly' do
          group = subject.to_network[:group]
          expect(group).to eq [
            described_class::GRAPH_NETWORK_NODE_GROUP[subject.kind],
            described_class::GRAPH_NETWORK_NODE_GROUP_BOOST[:is_aggregable],
          ].sum
        end

      end

      context 'for non default, non composite, non aggregable role' do

        subject { build(:node, :role, :not_default, :not_composite, :not_aggregable, :not_aggregable_by_roles) }

        it 'builds node title attribute correctly' do
          title = subject.to_network[:title]
          expect(title).to include("#{subject.attrs[:kind]}: #{subject.attrs[:name]}")
          expect(title).not_to include("- Default k8s role")
          expect(title).not_to include("- Aggregates rules defined in other cluster roles")
          expect(title).not_to include("- Can be aggregated by cluster roles: #{subject.attrs[:aggregable_by]}")
        end

        it 'builds node group attribure correctly' do
          group = subject.to_network[:group]
          expect(group).to eq described_class::GRAPH_NETWORK_NODE_GROUP[subject.kind]
        end

      end

    end


    context 'for :Subject node kind' do

      subject { build(:node, :subject) }

      it 'returns a map representation of a given node for use in the network view' do
        map = subject.to_network
        expect(map.keys.size).to eq 5
        expect(map).to include( # group / title tested above
          id:    subject.label,
          label: "#{subject.attrs[:kind]}: #{subject.attrs[:name]}",
          value: nil
        )
      end

      it 'builds network node title correctly' do
        title = subject.to_network[:title]
        expect(title).to include("#{subject.attrs[:kind]}: #{subject.attrs[:name]}")
      end

      it 'builds node group attribure correctly' do
        group = subject.to_network[:group]
        expect(group).to eq described_class::GRAPH_NETWORK_NODE_GROUP[subject.kind]
      end

    end

    context 'for :Namespace node kind' do

      subject { build(:node, :namespace) }

      it 'returns a map representation of a given node for use in the network view' do
        map = subject.to_network
        expect(map.keys.size).to eq 5
        expect(map).to include( # group / title tested above
          id:    subject.label,
          label: "#{subject.kind}: #{subject.attrs[:name]}",
          value: nil
        )
      end

      it 'builds network node title correctly' do
        title = subject.to_network[:title]
        expect(title).to include("#{subject.attrs[:kind]}: #{subject.attrs[:name]}")
      end

      it 'builds node group attribure correctly' do
        group = subject.to_network[:group]
        expect(group).to eq described_class::GRAPH_NETWORK_NODE_GROUP[subject.kind]
      end

    end

    context 'for all supported node kinds' do

      context 'with no :kind and :name keys present in node attrs' do

        subject { build(:node, :namespace, attrs: {} ) }

        it 'builds node title attribute correctly' do
          title = subject.to_network[:title]
          expect(title).to include("#{subject.kind}: #{subject.label}")
        end

      end

      context 'with :kind and :name keys present in node attrs' do

        let(:attr_kind) { 'some-kind' }
        let(:attr_name) { 'some-name' }
        subject { build(:node, :subject, attrs: { kind: attr_kind, name: attr_name } ) }

        it 'builds node title attribute correctly' do
          title = subject.to_network[:title]
          expect(title).to include("#{attr_kind}: #{attr_name}")
        end

      end

    end

  end

end
