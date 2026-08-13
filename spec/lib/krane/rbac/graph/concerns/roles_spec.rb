RSpec.describe Krane::Rbac::Graph::Concerns::Roles do

  # testing with builder using this concern
  subject { Krane::Rbac::Graph::Builder.new path: double, options: OpenStruct.new(verbose: false) }

  describe '#roles' do

    let(:role) { build(:role) }

    before do
      allow(subject).to receive(:iterate).with(:roles).and_yield(role)      
    end

    it 'will iterate through roles and process them' do
      expect(subject).to receive(:setup_role).with(role_kind: :Role, role: role)
      subject.roles
    end

  end

  describe '#cluster_roles' do

    let(:cluster_role) { build(:cluster_role) }

    before do
      allow(subject).to receive(:iterate).with(:clusterroles).and_yield(cluster_role)
    end

    it 'will iterate through cluster roles and process them' do
      expect(subject).to receive(:setup_role).with(role_kind: :ClusterRole, role: cluster_role)
      subject.cluster_roles
    end

    context 'for cluster roles with aggregation rules referencing other roles' do

      let(:aggregable_roles_map) do
        # aggregating_role -> [ composite_roles ]
        {
          'aggr1' => [
            'comp1',
            'comp2'
          ]
        }
      end

      before do
        subject.instance_variable_set(:@aggregable_roles, aggregable_roles_map)
        allow(subject).to receive(:setup_role).with(role_kind: :ClusterRole, role: cluster_role)
        allow(subject).to receive(:edge).and_call_original
      end

      it 'creates :AGGREGATE edges betweeen those roles' do
        expect(subject).to receive(:edge).with(:aggregate, {
          aggregating_role_name: 'aggr1', 
          composite_role_name:   'comp1'
        })
        expect(subject).to receive(:edge).with(:aggregate, {
          aggregating_role_name: 'aggr1', 
          composite_role_name:   'comp2'
        })

        subject.cluster_roles
      end

      it 'creates :COMPOSITE edges betweeen those roles' do
        expect(subject).to receive(:edge).with(:composite, {
          aggregating_role_name: 'aggr1', 
          composite_role_name:   'comp1'
        })
        expect(subject).to receive(:edge).with(:composite, {
          aggregating_role_name: 'aggr1', 
          composite_role_name:   'comp2'
        })

        subject.cluster_roles
      end

    end

  end

  describe 'private methods' do

    describe '#setup_role' do

      let(:role_kind) { :Role }        
      let(:role) { build(:role, rules: build_list(:resource_rule, 1, verbs: ['list'])) }

      before do
        allow(subject).to receive(:node).and_call_original
        allow(subject).to receive(:edge).and_call_original
      end

      describe 'creates graph nodes and edges' do

        after do
          # call
          subject.send(:setup_role, role_kind: role_kind, role: role)
        end

        it 'creates :Namespace graph node' do
          expect(subject).to receive(:node).with(:namespace, { 
            name: role[:metadata][:namespace]
          })
        end

        it 'creates :Role graph node' do
          expect(subject).to receive(:node).with(:role, { 
            kind:          role_kind, 
            name:          role[:metadata][:name], 
            is_default:    false, 
            is_composite:  false,
            is_aggregable: false, 
            aggregable_by: '',
            version:       role[:metadata][:resourceVersion],
            created_at:    role[:metadata][:creationTimestamp]
          })
        end

        it 'creates :Rule graph node' do
          expect(subject).to receive(:node).with(:rule, { 
            rule: subject.process_resource_rule(role[:rules].first).first
          })
        end

        it 'creates :SCOPE graph edge between :Role and :Namespace nodes' do
          expect(subject).to receive(:edge).with(:scope, { 
            role_kind: role_kind, 
            role_name: role[:metadata][:name], 
            namespace: role[:metadata][:namespace]
          })
        end

        it 'creates :GRANT graph edge between :Role and :Rule nodes' do
          expect(subject).to receive(:edge).with(:grant, { 
            role_kind: role_kind, 
            role_name: role[:metadata][:name], 
            rule:      subject.process_resource_rule(role[:rules].first).first
          })
        end

        it 'creates :SECURITY graph edge between :Rule and :Psp nodes' do
          expect(subject).to receive(:edge).with(:security, { 
            rule: subject.process_resource_rule(role[:rules].first).first
          })
        end

      end

      it 'adds elements to role namespace lookup and list of defined roles' do
        # call
        subject.send(:setup_role, role_kind: role_kind, role: role)

        role_ns_lookup = subject.instance_variable_get(:@role_ns_lookup)
        defined_roles  = subject.instance_variable_get(:@defined_roles)
        default_roles  = subject.instance_variable_get(:@default_roles)

        expect(role_ns_lookup).to include(
          role[:metadata][:name] => role[:metadata][:namespace]
        )

        expect(defined_roles).to include(
          role_kind: :Role,
          role_name: role[:metadata][:name]
        )

        expect(default_roles).to be_empty
      end

      it 'populates node and edge buffers correctly' do
        # call
        subject.send(:setup_role, role_kind: role_kind, role: role)

        node_buffer = subject.instance_variable_get(:@node_buffer)
        edge_buffer = subject.instance_variable_get(:@edge_buffer)

        expect(node_buffer.size).to eq 3          
        
        # There is no podsecuritypolicies resource related rule in the 
        # role so expect only 2 edges as it won't include :SECURITY edge.
        # If role included resource rule for `podsecuritypolicies` and 
        # specific resource name then it'd contain 3 edges
        expect(edge_buffer.size).to eq 2 
        security_edge = edge_buffer.find {|e| e.relation == :SECURITY}
        expect(security_edge).to be_nil
      end

      context 'for role with `podsecuritypolicies` resource rule present and psp name specified' do

        let(:role) do
          build(:role, rules: build_list(
            :resource_rule, 1, 
            resources: ['podsecuritypolicies'], 
            resource_names: ['privileged-psp'], 
            verbs: ['list']))
        end

        it 'populates edge buffers correctly' do
          # call
          subject.send(:setup_role, role_kind: role_kind, role: role)

          edge_buffer = subject.instance_variable_get(:@edge_buffer)

          security_edge = edge_buffer.find {|e| e.relation == :SECURITY}
          
          expect(security_edge).not_to be_nil 
        end

      end

      context 'for role without access rules' do

        let(:role) { build(:role, rules: []) }

        it 'does not add :Rule node and :GRANT edge' do
          expect(subject).to receive(:node).with(:rule, anything).never
          expect(subject).to receive(:edge).with(:grant, anything).never
          expect(subject).to receive(:edge).with(:security, anything).never

          # call
          subject.send(:setup_role, role_kind: role_kind, role: role)
        end

      end

      context 'with default (built-in) role' do

        let(:role) { build(:role, :default) }

        it 'adds that role to default roles' do
          # call
          subject.send(:setup_role, role_kind: role_kind, role: role)

          default_roles = subject.instance_variable_get(:@default_roles)
          expect(default_roles).to include(
            role_kind: :Role,
            role_name: role[:metadata][:name]
          )
        end

      end

      context 'with cluster role containing aggregate-to-xxxxx labels' do

        let(:role_kind) { :ClusterRole }
        let(:role)      { build(:cluster_role, :with_aggregate_to_labels) }

        it 'builds the aggregable roles lookup and creates :Role node with `is_aggregable` flag set to true' do
          # :cluster_role :with_aggregate_to_labels factory injects two labels to the role definition
          #
          # {
          #   "rbac.authorization.k8s.io/aggregate-to-admin": "true",
          #   "rbac.authorization.k8s.io/aggregate-to-edit": "true"
          # } 

          # call
          subject.send(:setup_role, role_kind: role_kind, role: role)

          node_buffer = subject.instance_variable_get(:@node_buffer)
          role_node   = node_buffer.find {|n| n[:kind] == :Role}

          expect(role_node.attrs).to include(
            kind:          role_kind, 
            name:          role[:metadata][:name], 
            defined:       true,
            is_default:    false, 
            is_composite:  false,
            is_aggregable: true, 
            aggregable_by: "admin, edit",
            version:       role[:metadata][:resourceVersion],
            created_at:    role[:metadata][:creationTimestamp]
          )

          aggregable_roles = subject.instance_variable_get(:@aggregable_roles)
          expect(aggregable_roles).to include(
            'admin' => [ role[:metadata][:name] ],
            'edit'  => [ role[:metadata][:name] ],
          )
        end

      end

      context 'with cluster role with aggregationRule defined' do

        let(:role_kind) { :ClusterRole }
        let(:role)      { build(:cluster_role, :with_aggregation_rules) }

        it 'creates :Role node with `is_composite` flag set to true' do
          # call
          subject.send(:setup_role, role_kind: role_kind, role: role)

          node_buffer = subject.instance_variable_get(:@node_buffer)
          role_node   = node_buffer.find {|n| n[:kind] == :Role}

          expect(role_node.attrs).to include(
            kind:          role_kind, 
            name:          role[:metadata][:name], 
            defined:       true,
            is_default:    false, 
            is_composite:  true,
            is_aggregable: false, 
            aggregable_by: '',
            version:       role[:metadata][:resourceVersion],
            created_at:    role[:metadata][:creationTimestamp]
          )
        end

      end

    end

  end

end
