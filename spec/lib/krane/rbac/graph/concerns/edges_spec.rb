RSpec.shared_examples "an edge builder" do |args|

  let(:src_node_label)  { "#{Krane::Rbac::Graph::Builder::NODE_LABEL_PREFIX}1" }
  let(:dest_node_label) { "#{Krane::Rbac::Graph::Builder::NODE_LABEL_PREFIX}2" }

  it args[:title] do
    expected_args = [
      src_node_label, args[:relation].upcase.to_sym, dest_node_label
    ].tap do |a|
      a << args[:direction] unless args[:direction].blank?
    end

    expect(subject).to receive(:add_relation).with(*expected_args)

    subject.send("edge_#{args[:relation].downcase}".to_sym, args[:params])
  end

end

RSpec.describe Krane::Rbac::Graph::Concerns::Edges do

  # testing with builder using this concern
  subject do
    Krane::Rbac::Graph::Builder.new path: '/some-path', options: OpenStruct.new(verbose: false)
  end

  describe '#edges' do

    context 'with egde buffer present' do

      let(:direction) { '->' }
      let(:edges) { build_list(:edge, 1, direction: direction) }

      before do
        subject.instance_variable_set(:@edge_buffer, edges)
      end

      it 'maps all elements in buffer to their string representation' do
        res = subject.edges
        e   = edges.first 
        expect(res).to include(
          "(#{e.source_label})-[:#{e.relation}]#{direction}(#{e.destination_label})"
        )
      end

    end

    context 'without any edge in the buffer' do

      it 'returns empty Set' do
        expect(subject.edges).to be_empty
      end

    end

  end

  describe '#network_edges' do

    context 'with egde buffer present' do

      let(:direction) { '->' }
      let(:edges)    { build_list(:edge, 1, direction: direction) }

      before do
        subject.instance_variable_set(:@edge_buffer, edges)
      end

      it 'maps all elements in buffer to their network representation' do
        res = subject.network_edges
        e   = edges.first 
        expect(res).to include(
          from: e.source_label, 
          to:   e.destination_label
        )
      end

    end

    context 'without any edge in the buffer' do

      it 'returns empty Set' do
        expect(subject.network_edges).to be_empty
      end

    end

  end

  describe 'private methods' do

    describe '#add_relation' do

      let(:source_label)      { 'source_label' }
      let(:relation)          { :SOME_RELATION_NAME }
      let(:destination_label) { 'destination_label' }
      let(:direction)         { '<->' }

      before do
        subject.send(:add_relation, source_label, relation, destination_label, direction)
      end

      it 'adds an Edge to graph edge buffer' do
        edge = subject.instance_variable_get(:@edge_buffer).first

        expect(edge.class).to             eq Krane::Rbac::Graph::Edge
        expect(edge.source_label).to      eq source_label
        expect(edge.relation).to          eq relation
        expect(edge.destination_label).to eq destination_label
        expect(edge.direction).to         eq direction
      end

      it 'increase node weights for source and destination nodes' do
        node_weights = subject.instance_variable_get(:@node_weights)

        expect(node_weights[source_label]).to eq 1
        expect(node_weights[destination_label]).to eq 1
      end

    end

    #== :SCOPE

    describe '#edge_scope' do

      it_behaves_like "an edge builder", relation: :SCOPE, params: { 
          role_kind: :Role, 
          role_name: 'some-name', 
          namespace: 'some-ns' 
        }, title: 'creates a :SCOPE edge between :Role (Role/ClusterRole) and :Namespace nodes'
        
    end

    #== :ACCESS

    describe '#edge_access' do

      it_behaves_like "an edge builder", relation: :ACCESS, params: { 
          subject_kind: :User, 
          subject_name: 'some-name', 
          namespace:    'some-ns'
        },  title: 'creates a :ACCESS edge between :Subject and :Namespace nodes'

    end

    #== :GRANT

    describe '#edge_access' do

      it 'creates a :GRANT edge between :Role and :Rule (access definition) nodes' do
        expect(subject).to receive(:add_relation).with(
          "#{Krane::Rbac::Graph::Builder::NODE_LABEL_PREFIX}1",
          :GRANT, 
          "#{Krane::Rbac::Graph::Builder::NODE_LABEL_PREFIX}2",
        )

        subject.send(:edge_grant, role_kind: :Role, role_name: 'some-name', rule: build(:rule))
      end

      # it_behaves_like "an edge builder", relation: :GRANT, params: { 
      #     role_kind: :Role,
      #     role_name: 'some-name',
      #     rule: FactoryBot.build(:rule)
      #   }, title: 'creates a :GRANT edge between :Role and :Rule (access definition) nodes'

    end

    #== :SECURITY

    describe '#edge_security' do

      context 'with `podsecuritypolicies` resource' do

        let(:rule) do
          build(:resource_rule, resources: ['podsecuritypolicies'], resource_names: resource_names, verbs: ['get'])
        end

        context 'and resource name specified' do

          let(:resource_names) { ['privileged'] }

          it 'creates a :SECURITY edge between :Rule (Role/ClusterRole rule) and :Psp (PodSecurityPolicy) nodes' do
            expect(subject).to receive(:add_relation).with(
              "#{Krane::Rbac::Graph::Builder::NODE_LABEL_PREFIX}1",
              :SECURITY, 
              "#{Krane::Rbac::Graph::Builder::NODE_LABEL_PREFIX}2",
            )

            subject.send(:edge_security, rule: subject.process_resource_rule(rule).first)
          end

          # it_behaves_like "an edge builder", relation: :SECURITY, params: { 
          #   rule: subject.process_resource_rule(rule).first
          # }, title: 'creates a :SECURITY edge between :Rule (Role/ClusterRole rule) and :Psp (PodSecurityPolicy) nodes'

        end

        context 'and unspecified resource name' do

          let(:resource_names) { nil }

          it 'does nothing' do
            expect(subject).to receive(:add_relation).never
            subject.send(:edge_security, rule: subject.process_resource_rule(rule).first)
          end

        end

      end

      context 'with resource different than `podsecuritypolicies`' do

        let(:rule) do
          build(:resource_rule, resources: ['pods'], verbs: ['get'])
        end

        it 'does nothing' do
          expect(subject).to receive(:add_relation).never
          subject.send(:edge_security, rule: subject.process_resource_rule(rule).first)
        end

      end

    end

    #== :ASSIGN

    describe '#edge_assign' do

      it_behaves_like "an edge builder", relation: :ASSIGN, params: { 
          role_kind:    :Role, 
          role_name:    'some-name', 
          subject_kind: :User, 
          subject_name: 'some-subject'
        }, title: 'creates a :ASSIGN edge between :Role and :Rule (access definition) nodes'

    end

    #== :ASSIGN

    describe '#edge_relation' do

      it_behaves_like "an edge builder", relation: :RELATION, params: { 
          a_subject_kind: :User, 
          a_subject_name: 'user', 
          b_subject_kind: :Group, 
          b_subject_name: 'group'
        }, title: 'creates a :RELATION edge between two :Subject nodes'

    end

    #== :AGGREGATE

    describe '#edge_aggregate' do

      it_behaves_like "an edge builder", relation: :AGGREGATE, params: { 
          aggregating_role_name: 'r1',
          composite_role_name: 'r2'
        }, direction: '->',
        title: 'creates an :AGGREGATE edge between two :Role nodes (with ClusterRole kind)'

    end

    #== :AGGREGATE

    describe '#edge_composite' do

      it_behaves_like "an edge builder", relation: :COMPOSITE, params: { 
          aggregating_role_name: 'r1', 
          composite_role_name: 'r2'
        }, direction: '<-',
        title: 'creates a :COMPOSITE edge between two :Role nodes (with ClusterRole kind)'


    end

  end

end
