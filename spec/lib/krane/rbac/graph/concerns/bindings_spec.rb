RSpec.describe Krane::Rbac::Graph::Concerns::Bindings do

  # testing with builder using this concern
  subject { Krane::Rbac::Graph::Builder.new path: double, options: OpenStruct.new(verbose: false) }

  describe '#role_bindings' do

    let(:binding) { build(:binding, :for_role) }

    before do
      allow(subject).to receive(:iterate).with(:rolebindings).and_yield(binding)
    end

    it 'will iterate through role bindings and process them' do
      expect(subject).to receive(:setup_binding).with(binding_kind: :RoleBinding, binding: binding)
      subject.role_bindings
    end

  end

  describe '#cluster_role_bindings' do

    let(:binding) { build(:binding, :for_cluster_role) }

    before do
      allow(subject).to receive(:iterate).with(:clusterrolebindings).and_yield(binding)
    end

    it 'will iterate through cluster role bindings and process them' do
      expect(subject).to receive(:setup_binding).with(binding_kind: :ClusterRoleBinding, binding: binding)
      subject.cluster_role_bindings
    end

  end

  describe 'private methods' do

    describe '#setup_binding' do

      let(:binding_kind) { :RoleBinding }        
      let(:binding) { build(:binding, :for_role) }

      before do
        allow(subject).to receive(:node).and_call_original
        allow(subject).to receive(:edge).and_call_original
      end

      context 'for RoleBinding' do

        it 'create :Namespace graph node for namespace referenced in the binding' do
          expect(subject).to receive(:node).with(:namespace, { 
            name: binding[:metadata][:namespace]
          }).at_least(:once)

          # call
          subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)
        end

      end

      context 'for ClusterRoleBinding' do

        let(:binding) { build(:binding, :for_cluster_role) }

        it 'create :Namespace graph node for default namespace `*` (cluster-wide)' do
          expect(subject).to receive(:node).with(:namespace, { 
            name: Krane::Rbac::Graph::Builder::ALL_NAMESPACES_PLACEHOLDER
          }).at_least(:once)

          # call
          subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)
        end

      end

      it 'create :Subject graph node for subject referenced in the binding' do
        expect(subject).to receive(:node).with(:subject, { 
          kind: binding[:subjects].first[:kind],
          name: binding[:subjects].first[:name]
        })

        # call
        subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)
      end

      it 'create :SCOPE edge between :Role and :Namespace nodes' do
        expect(subject).to receive(:edge).with(:scope, { 
          role_kind: binding[:roleRef][:kind], 
          role_name: binding[:roleRef][:name], 
          namespace: binding[:metadata][:namespace]
        })

        # call
        subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)
      end

      it 'create :ASSIGN edge between :Role and :Subject nodes' do
        expect(subject).to receive(:edge).with(:assign, { 
          role_kind: binding[:roleRef][:kind], 
          role_name: binding[:roleRef][:name], 
          subject_kind: binding[:subjects].first[:kind], 
          subject_name: binding[:subjects].first[:name]
        })

        # call
        subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)
      end

      it 'create :ACCESS edge between :Subject and :Namespace nodes' do
        expect(subject).to receive(:edge).with(:access, { 
          subject_kind: binding[:subjects].first[:kind], 
          subject_name: binding[:subjects].first[:name],
          namespace: binding[:metadata][:namespace]
        })

        # call
        subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)
      end

      it 'adds bound role to referenced roles set' do
        # call
        subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)

        referenced_roles = subject.instance_variable_get(:@referenced_roles)

        expect(referenced_roles).to include(
          role_kind:    binding[:roleRef][:kind], 
          role_name:    binding[:roleRef][:name]
        )
      end

      context 'when role referenced in the binding is already defined' do

        before do
          # pre-setting defined roles lookup
          subject.instance_variable_set(:@defined_roles, [
            {
              role_kind: binding[:roleRef][:kind], 
              role_name: binding[:roleRef][:name]
            }
          ])

          allow(subject).to receive(:node).and_call_original
        end

        it 'does not create missing :Role graph nodes' do
          expect(subject).to receive(:node).with(:role, { 
            kind: binding[:roleRef][:kind],
            name: binding[:roleRef][:name],
            defined: false
          }).never

          # call
          subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)
        end

      end

      context 'when role referenced in the binding is not defined' do

        # This assumes Roles have not been processed yet, or Roles lookup doesn't contain
        # roles referenced in the binding

        before do
          allow(subject).to receive(:node).and_call_original
        end

        it 'creates missing :Role node with `disabled` flag set to true' do
          expect(subject).to receive(:node).with(:role, { 
            kind: binding[:roleRef][:kind],
            name: binding[:roleRef][:name],
            defined: false
          })

          # call
          subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)
        end

        it 'records undefined role' do
          # call
          subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)

          undefined_roles = subject.instance_variable_get(:@undefined_roles)

          expect(undefined_roles).to include(
            role_kind:    binding[:roleRef][:kind], 
            role_name:    binding[:roleRef][:name], 
            binding_kind: binding_kind, 
            binding_name: binding[:metadata][:name]
          )
        end

      end

      context 'for binding without any subjects' do

        let(:binding) { build(:binding, :for_role, subjects: []) }

        it 'records binding without subjects' do
          # call
          subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)

          bindings_without_subject = subject.instance_variable_get(:@bindings_without_subject)

          expect(bindings_without_subject).to include(
            binding_kind: binding_kind, 
            binding_name: binding[:metadata][:name]
          )
        end

      end

      context 'for binding containing more that one subject' do

        let(:binding) do
          build(:binding, :for_role, subjects: [
            build(:subject, :user),
            build(:subject, :service_account)
          ])
        end

        before do
          allow(subject).to receive(:edge).and_call_original
        end

        it 'sets a :RELATION edge between any two subjects' do          
          expect(subject).to receive(:edge).with(:relation, { 
            a_subject_kind: binding[:subjects].first[:kind],
            a_subject_name: binding[:subjects].first[:name],
            b_subject_kind: binding[:subjects].last[:kind],
            b_subject_name: binding[:subjects].last[:name]
          })

          # call
          subject.send(:setup_binding, binding_kind: binding_kind, binding: binding)
        end

      end

    end

  end

end
