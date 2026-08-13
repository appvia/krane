RSpec.describe Krane::Visualisations::TreeView::Element do

  # Mirrors the columns returned by TreeView::Builder#query_graph
  def record overrides = {}
    {
      namespace_name:      'team-a',
      subject_kind:        'ServiceAccount',
      subject_name:        'default',
      subject_namespace:   'team-a',
      role_kind:           'Role',
      role_name:           'developer',
      role_is_default:     'false',
      role_is_composite:   'false',
      role_is_aggregable:  'false',
      rule_type:           'resource',
      rule_api_group:      'core',
      rule_resource:       'pods',
      rule_resource_name:  'NULL',
      rule_url:            'NULL',
      rule_verb:           'get'
    }.merge(overrides)
  end

  # TreeView::Builder seeds an infinitely nested Hash
  def new_facets
    Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }
  end

  def build_facets(*records, key:)
    new_facets.tap do |facets|
      records.each { |r| described_class.new(r).build(facets: facets, with_keys: [key]) }
    end
  end

  describe '#subjects' do

    # ServiceAccounts are namespaced, so `default` in team-a and `default` in team-b are separate
    # principals. Keying the facet on subject name alone merges them into one tree entry, showing
    # the union of two principals' access under a single node.
    context 'for ServiceAccounts sharing a name across different namespaces' do

      let(:facets) do
        build_facets(
          record(subject_namespace: 'team-a', namespace_name: 'team-a'),
          record(subject_namespace: 'team-b', namespace_name: 'team-b'),
          key: :subjects
        )
      end

      # facet nesting: { {tag: :Actor, text: kind} => { {tag: kind, text: <actor>} => ... } }
      let(:actors) { facets[:subjects].values.first.keys }

      it 'creates a distinct tree entry per namespace' do
        expect(actors.size).to eq 2
      end

      it 'labels each entry with its own namespace' do
        expect(actors.map { |a| a[:text] }).to contain_exactly(
          'default (team-a)', 'default (team-b)'
        )
      end

    end

    context 'for a subject kind which is not namespaced' do

      let(:facets) do
        build_facets(record(subject_kind: 'User', subject_name: 'alice', subject_namespace: 'NULL'), key: :subjects)
      end

      let(:actors) { facets[:subjects].values.first.keys }

      it 'leaves the subject name undecorated' do
        expect(actors.map { |a| a[:text] }).to eq ['alice']
      end

    end

  end

  describe '#namespaces' do

    context 'for ServiceAccounts sharing a name across different namespaces' do

      let(:facets) do
        build_facets(
          record(subject_namespace: 'team-a'),
          record(subject_namespace: 'team-b'),
          key: :namespaces
        )
      end

      # namespaces facet nests Namespace -> admits -> subject_kind -> subject
      let(:actors) do
        facets[:namespaces].values.first.values.first.keys
      end

      it 'distinguishes the two subjects' do
        expect(actors.map { |a| a[:text] }).to contain_exactly(
          'default (team-a)', 'default (team-b)'
        )
      end

    end

  end

end
