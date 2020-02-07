RSpec.describe Krane::Rbac::Graph::Edge do

  subject { described_class }

  describe '#new' do

    context 'with correct attributes' do

      subject { build(:edge) }

      it 'creates a new Edge object' do
        expect { subject }.not_to raise_error
        expect(subject).not_to   be nil
      end

    end

    context 'with invalid / not defined properties' do

      subject { build(:edge, :invalid) }

      it 'fails to instantiate a new Edge object and throws an exception' do
        expect { subject }.to raise_error(
          NoMethodError, "The property 'unknown_property' is not defined for Krane::Rbac::Graph::Edge."
        )
      end

    end

  end

  describe '#to_s' do

    context 'for source node referencing destination node (direction: ->)' do

      subject { build(:edge, direction: '->') }

      it 'returns string representation of the edge to be indexed in the graph' do
        expect(subject.to_s).to eq %Q((#{subject.source_label})-[:#{subject.relation}]->(#{subject.destination_label}))
      end

    end

    context 'for source node referenced by destination node (direction: <-)' do

      subject { build(:edge, direction: '<-') }

      it 'returns string representation of the edge to be indexed in the graph' do
        expect(subject.to_s).to eq %Q((#{subject.source_label})<-[:#{subject.relation}]-(#{subject.destination_label}))
      end

    end

    context 'for bidirectional edge (direction: <->)' do

      subject { build(:edge, direction: '<->') }

      it 'returns string representation of the edge to be indexed in the graph' do
        expect(subject.to_s).to eq [
          %Q((#{subject.source_label})-[:#{subject.relation}]->(#{subject.destination_label})),
          %Q((#{subject.source_label})<-[:#{subject.relation}]-(#{subject.destination_label}))
        ].join(',')
      end

    end

  end

  describe '#to_network' do

    context 'for unsuported edge type' do

      context ':SECURITY' do

        subject { build(:edge, :security) }

        it 'returns nil' do
          expect(subject.to_network).to be_nil
        end

      end

      context ':GRANT' do

        subject { build(:edge, :grant) }

        it 'returns nil' do
          expect(subject.to_network).to be_nil
        end

      end

      context ':RELATION' do

        subject { build(:edge, :relation) }

        it 'returns nil' do
          expect(subject.to_network).to be_nil
        end

      end

      context ':SCOPE' do

        subject { build(:edge, :scope) }

        it 'returns nil' do
          expect(subject.to_network).to be_nil
        end

      end

    end

    context 'for supported edge type' do

      context ':ACCESS' do

        subject { build(:edge, :access) }

        it 'returns a map representation of a given edge for use in the network view' do
          expect(subject.to_network).to include(
            from: subject.source_label,
            to:   subject.destination_label
          )
        end

      end

      context ':ASSIGN' do

        subject { build(:edge, :assign) }

        it 'returns a map representation of a given edge for use in the network view' do
          expect(subject.to_network).to include(
            from: subject.source_label,
            to:   subject.destination_label
          )
        end

      end

      context ':AGGREGATE' do

        subject { build(:edge, :aggregate) }

        it 'returns a map representation of a given edge for use in the network view' do
          expect(subject.to_network).to include(
            from: subject.source_label,
            to:   subject.destination_label
          )
        end

      end

      context ':COMPOSITE' do

        subject { build(:edge, :composite) }

        it 'returns a map representation of a given edge for use in the network view' do
          expect(subject.to_network).to include(
            from: subject.source_label,
            to:   subject.destination_label
          )
        end

      end

    end

  end

end
