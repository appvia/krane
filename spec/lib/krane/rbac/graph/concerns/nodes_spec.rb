RSpec.describe Krane::Rbac::Graph::Concerns::Nodes do

  # testing with builder using this concern
  subject do
    Krane::Rbac::Graph::Builder.new path: '/some-path', options: OpenStruct.new(verbose: false)
  end

  describe '#nodes' do

    context 'with nodes buffer present' do

      let(:nodes) { build_list(:node, 1) }

      before do
        subject.instance_variable_set(:@node_buffer, nodes)
      end

      it 'maps all elements in buffer to their string representation' do
        res  = subject.nodes
        node = nodes.first 
        expected_attrs = node.attrs.map {|k,v| "#{k.to_s}:'#{v.to_s}'"}.join(", ")
        expect(res).to include(
          "(#{node.label}:#{node.kind} {#{expected_attrs}})"
        )
      end

    end

    context 'without any node in the buffer' do

      it 'returns empty Set' do
        expect(subject.nodes).to be_empty
      end

    end

  end

  describe '#network_nodes' do

    context 'with node buffer present' do

      let(:nodes)    { build_list(:node, 1) }

      before do
        subject.instance_variable_set(:@node_buffer, nodes)
      end

      it 'maps all elements in buffer to their network representation' do
        res = subject.network_nodes
        n   = nodes.first 
        expect(res).to include(
          id:    n.label.delete_prefix(Krane::Rbac::Graph::Builder::NODE_LABEL_PREFIX),
          label: "#{n.kind}: #{n.attrs[:name]}",
          group: Krane::Rbac::Graph::Node::GRAPH_NETWORK_NODE_GROUP[n.kind],
          value: 0,
          title: "#{n.kind}: #{n.attrs[:name]}"
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

    describe '#add_node' do

      let(:kind)  { 'source_label' }
      let(:label) { :SOME_RELATION_NAME }
      let(:attrs) { {key: 'value'} }

      before do
        subject.send(:add_node, kind, label, attrs)
      end

      it 'adds a Node to graph node buffer' do
        node = subject.instance_variable_get(:@node_buffer).first

        expect(node.class).to eq Krane::Rbac::Graph::Node
        expect(node.kind).to  eq kind
        expect(node.label).to eq label
        expect(node.attrs).to eq attrs
      end

    end

    describe 'builders' do

      # label for each node will be generated in the same way
      let(:label)    { "#{Krane::Rbac::Graph::Builder::NODE_LABEL_PREFIX}1" }

      #== :Role

      describe '#node_role' do

        let(:role_attrs) { build(:role_node_attrs) }

        it 'creates :Role graph node for RBAC Role/ClusterRole' do
          expect(subject).to receive(:add_node).with(:Role, label, role_attrs)
          subject.send(:node_role, role_attrs)
        end

      end

      #== :Namespace

      describe '#node_namespace' do

        let(:ns_name) { 'some-name' }

        it 'creates :Namespace graph node' do
          expect(subject).to receive(:add_node).with(:Namespace, label, {name: ns_name})
          subject.send(:node_namespace, name: ns_name)
        end

      end

      #== :Rule

      describe '#node_rule' do

        let(:rule_attrs) { build(:rule_node_attrs, :for_resource) }

        it 'creates :Rule graph node for RBAC Role/ClusterRole rule' do
          expect(subject).to receive(:add_node).with(:Rule, label, rule_attrs)
          subject.send(:node_rule, rule: rule_attrs)
        end

      end

      #== :Psp

      describe '#node_psp' do

        let(:psp_attrs) { build(:psp_node_attrs) }

        it 'creates :Psp graph node for RBAC PodSecurityPolicy' do
          expect(subject).to receive(:add_node).with(:Psp, label, psp_attrs)
          subject.send(:node_psp, attrs: psp_attrs)
        end

      end

      #== :Subject

      describe '#node_subject' do

        let(:sub_kind) { :User }
        let(:sub_name) { 'some-user' }
        let(:subject_attrs) do
          { 
            kind: sub_kind, 
            name: sub_name 
          }
        end

        it 'creates :Subject graph node for subjects referenced in RoleBinging/ClusterRoleBinding' do
          expect(subject).to receive(:add_node).with(:Subject, label, subject_attrs)
          subject.send(:node_subject, kind: sub_kind, name: sub_name)
        end

      end

    end

  end

end
