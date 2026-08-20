RSpec.describe Krane::Clients::FalkorDB::QueryResult do

  # Positional property keys, the way FalkorDB reports them via db.propertyKeys
  let(:property_keys) { %w[name kind active] }

  let(:graph) do
    instance_double(Krane::Clients::FalkorDB::Graph,
      property_keys: property_keys,
      invalidate_property_keys: nil
    )
  end

  subject { described_class.new(response, graph: graph) }

  context 'when the query returns statistics only' do

    # CREATE and index queries answer with a single statistics row
    let(:response) { [["Nodes created: 1", "Query internal execution time: 0.5 milliseconds"]] }

    it 'should have no columns' do
      expect(subject.columns).to be_nil
    end

    it 'should have no resultset' do
      expect(subject.resultset).to be_nil
    end

  end

  context 'when the query returns scalar columns' do

    let(:response) do
      [
        [[1, "subject_name"], [1, "rank"], [1, "active"], [1, "score"], [1, "missing"]],
        [
          [[2, "alice"], [3, 3], [4, "true"], [5, "1.5"], [1, nil]],
          [[2, "bob"],   [3, 7], [4, "false"], [5, "2.0"], [1, nil]]
        ],
        []
      ]
    end

    it 'should expose the column names' do
      expect(subject.columns).to eq %w[subject_name rank active score missing]
    end

    it 'should decode each scalar to its Ruby type' do
      expect(subject.resultset).to eq [
        ["alice", 3, true, 1.5, nil],
        ["bob",   7, false, 2.0, nil]
      ]
    end

  end

  context 'when the query returns an array column' do

    # COLLECT(...) - the shape every aggregating risk rule relies on
    let(:response) do
      [
        [[1, "names"]],
        [[[6, [[2, "alice"], [2, "bob"]]]]],
        []
      ]
    end

    it 'should decode the array element by element' do
      expect(subject.resultset).to eq [[%w[alice bob]]]
    end

  end

  context 'when the query returns nested array columns' do

    let(:response) do
      [
        [[1, "pairs"]],
        [[[6, [[6, [[2, "alice"], [3, 3]]]]]]],
        []
      ]
    end

    it 'should decode recursively' do
      expect(subject.resultset).to eq [[[["alice", 3]]]]
    end

  end

  context 'when the query returns a node column' do

    # [ node_id, [label_ids], [[key_id, type, value], ...] ]
    let(:response) do
      [
        [[2, "s"]],
        [[[0, [0], [[0, 2, "alice"], [1, 2, "User"], [2, 4, "true"]]]]],
        []
      ]
    end

    it 'should decode the node properties into a hash' do
      expect(subject.resultset).to eq [[{ "name" => "alice", "kind" => "User", "active" => true }]]
    end

  end

  context 'when the query returns an edge column' do

    # [ edge_id, type_id, src_id, dest_id, [[key_id, type, value], ...] ]
    let(:response) do
      [
        [[3, "e"]],
        [[[0, 0, 0, 1, [[0, 2, "grant"]]]]],
        []
      ]
    end

    it 'should decode the edge properties into a hash' do
      expect(subject.resultset).to eq [[{ "name" => "grant" }]]
    end

  end

  context 'when the query returns no rows' do

    let(:response) { [[[1, "subject_name"]], [], []] }

    it 'should return an empty resultset' do
      expect(subject.resultset).to eq []
    end

  end

  context 'when a property was created after the keys were cached' do

    let(:property_keys) { %w[name] }

    let(:response) do
      [
        [[2, "s"]],
        [[[0, [0], [[0, 2, "alice"], [1, 2, "User"]]]]],
        []
      ]
    end

    it 'should invalidate the cache so the new key can be resolved' do
      # Stands in for Graph memoising db.propertyKeys until it is invalidated
      cached = %w[name]
      allow(graph).to receive(:property_keys) { cached }
      allow(graph).to receive(:invalidate_property_keys) { cached = %w[name kind] }

      expect(subject.resultset).to eq [[{ "name" => "alice", "kind" => "User" }]]
      expect(graph).to have_received(:invalidate_property_keys)
    end

  end

end
