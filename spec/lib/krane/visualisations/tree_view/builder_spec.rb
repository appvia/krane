require 'spec_helper'

describe Krane::Visualisations::TreeView::Builder do

  # The columns TreeView::Builder#query_graph projects, in order.
  def columns
    %w[
      namespace_name subject_kind subject_name subject_namespace
      role_kind role_name role_is_default role_is_composite role_is_aggregable
      rule_type rule_api_group rule_resource rule_resource_name rule_url rule_verb
    ]
  end

  # One row as the graph returns it: values positionally matching the columns.
  def row namespace:, subject: 'default', role: 'developer', resource: 'pods'
    [
      namespace, 'ServiceAccount', subject, namespace,
      'Role', role, 'false', 'false', 'false',
      'resource', 'core', resource, 'NULL', 'NULL', 'get'
    ]
  end

  # Stands in for the RedisGraph client, handing back a fixed resultset.
  def graph_returning *rows
    double(query: double(columns: columns, resultset: rows))
  end

  # The tree, without going near the graph or the filesystem: Writer is covered
  # separately, and the client is reached for in the constructor.
  def tree_for *rows
    allow(Krane::Clients::RedisGraph).to receive(:client).and_return(graph_returning(*rows))
    described_class.new(OpenStruct.new(cluster: 'test', verbose: false)).send(:prepare_data)
  end

  def facet tree, text
    tree[:nodes].find { |node| node[:text] == text }
  end

  describe '#prepare_data' do

    # The query used to carry an ORDER BY purely so that the facet hash came out
    # in display order. RedisGraph pays for that sort in memory, so ordering is
    # applied here instead - which only holds if it does not depend on the order
    # rows arrive in.
    context 'when the graph returns rows out of order' do

      let(:tree) do
        tree_for(
          row(namespace: 'team-c'),
          row(namespace: 'team-a'),
          row(namespace: 'team-b')
        )
      end

      it 'sorts the top level of a facet by name' do
        expect(facet(tree, 'Namespaces')[:nodes].map { |n| n[:text] }).to eq %w[team-a team-b team-c]
      end

      it 'sorts levels below the top by name' do
        namespaces = tree_for(
          row(namespace: 'team-a', resource: 'secrets'),
          row(namespace: 'team-a', resource: 'configmaps')
        )

        resources = facet(namespaces, 'Namespaces')[:nodes]
                      .first[:nodes].first[:nodes].first[:nodes].first[:nodes]

        expect(resources.map { |n| n[:text] }).to eq ['[core] configmaps', '[core] secrets']
      end
    end

    context 'for every facet' do

      let(:tree) { tree_for(row(namespace: 'team-b'), row(namespace: 'team-a')) }

      it 'names the root after the cluster' do
        expect(tree[:text]).to eq 'test cluster'
      end

      it 'builds all four branches' do
        expect(tree[:nodes].map { |n| n[:facet] }).to eq %i[namespaces subjects roles resources]
      end

      it 'fills each branch' do
        expect(tree[:nodes].map { |n| n[:nodes].size }).to all(be > 0)
      end
    end
  end
end
