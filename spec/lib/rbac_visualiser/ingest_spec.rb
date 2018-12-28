RSpec.describe 'RbacVisualiser::Ingest' do

  describe '#new' do
    context 'with missing cluster name' do
      it 'should raise an exception' do
        expect { RbacVisualiser::Ingest.new({}) }.to raise_exception KeyError, "key not found: :cluster"
      end
    end
  end

  describe '#run' do
    let(:kubectl_context) { 'some-context' }
    let(:cluster) { 'some-cluster' }
    let(:path) { "#{RbacVisualiser::Ingest::RBAC_CACHE_DIR}/#{cluster}" }

    context 'with indexing disabled' do
      context 'with kubectlcontext flag provided' do
        subject do
          RbacVisualiser::Ingest.new(cluster: cluster, kubectlcontext: kubectl_context, index: false)
        end

        it 'will fetch RBAC from running cluster via kubectl' do
          expect(subject).to receive(:fetch_rbac).with(kubectl_context, path) { true }
          subject.run
        end
      end
    end

    context 'with indexing enabled' do
      subject do
        RbacVisualiser::Ingest.new(cluster: cluster, index: true)
      end

      it 'indexes all RBAC resources' do
        allow(File).to receive(:exist?).with(anything) { true }

        expect(subject).to receive(:index_psp).with("#{path}/psp.yaml") { true }
        expect(subject).to receive(:index_roles).with("#{path}/roles.yaml") { true }
        expect(subject).to receive(:index_cluster_roles).with("#{path}/clusterroles.yaml") { true }
        expect(subject).to receive(:index_role_bindings).with("#{path}/rolebindings.yaml") { true }
        expect(subject).to receive(:index_cluster_role_bindings).with("#{path}/clusterrolebindings.yaml") { true }

        allow_any_instance_of(RedisGraph).to receive(:query) { true }

        subject.run
      end
    end
  end

  describe 'private methods' do

    subject(:subject) { RbacVisualiser::Ingest.new(cluster: 'test') }

    describe '#add_node' do
      let(:label) { 'some-label' }
      let(:kind) { :Role }
      let(:attrs) { '{name: "some-role"}' }

      it 'adds node to the graph buffer' do
        subject.send(:add_node, kind, label, attrs)
        expect(subject.instance_variable_get(:@buff)).to eq [%Q((#{label}:#{kind} #{attrs}))]
      end
    end

    describe '#add_relation' do
      let(:source_label) { 'source' }
      let(:destination_label) { 'destination' }
      let(:relation) { :ASSIGN }

      it 'adds an edge between the graph nodes' do
        subject.send(:add_relation, source_label, relation, destination_label)
        buffer = subject.instance_variable_get(:@buff)
        expect(buffer).to include %Q((#{source_label})-[:#{relation}]->(#{destination_label}))
        expect(buffer).to include %Q((#{source_label})<-[:#{relation}]-(#{destination_label}))
      end
    end

    describe '#index_psp' do
      let(:psp_name) { 'privileged' }
      let(:expected_psp_label) { subject.send(:make_label, :psp, psp_name) }
      let(:example_psp) do
        %Q(
          apiVersion: v1
          items:
          - apiVersion: extensions/v1beta1
            kind: PodSecurityPolicy
            metadata:
              name: #{psp_name}
              namespace: ""
            spec:
              allowPrivilegeEscalation: true
              allowedCapabilities:
              - '*'
              fsGroup:
                rule: RunAsAny
              hostIPC: true
              hostNetwork: true
              hostPID: true
              hostPorts:
              - max: 65536
                min: 1
              privileged: true
              runAsUser:
                rule: RunAsAny
              seLinux:
                rule: RunAsAny
              supplementalGroups:
                rule: RunAsAny
              volumes:
              - '*'
        )
      end

      before :each do
        expect(YAML).to receive(:load_file).with(anything) { YAML.load(example_psp) }
      end

      after :each do
        subject.send(:index_psp, "some_path_to_psp_yaml")
      end

      it 'index a new psp' do
        expect(subject).to receive(:add_node).with(:Psp, expected_psp_label, 
          %Q({
            name:"#{psp_name}",
            privileged:"true",
            allowPrivilegeEscalation:"true",
            allowedCapabilities:"*",
            volumes:"*",
            hostNetwork:"true",
            hostIPC:"true",
            hostIPD:"",
            runAsUser:"RunAsAny",
            seLinux:"RunAsAny",
            supplementalGroups:"RunAsAny",
            fsGroup:"RunAsAny"
          }).gsub(/[[:space:]]/,''))
      end
    end

    describe '#index_roles' do
      let(:role_name) { 'some:role-name' }
      let(:namespace) { 'some-namespace' }
      let(:expected_role_label) { subject.send(:make_label, :role, role_name) }
      let(:expected_namespace_label) { subject.send(:make_label, namespace) }
      let(:example_roles) do
        %Q(
          apiVersion: v1
          items:
          - apiVersion: rbac.authorization.k8s.io/v1
            kind: Role
            metadata:
              name: #{role_name}
              namespace: #{namespace}
            rules:
            - apiGroups:
              - ""
              resources:
              - configmaps
              verbs:
              - '*'
            - apiGroups:
              - policy
              resourceNames:
              - privileged
              resources:
              - podsecuritypolicies
              verbs:
              - use
            - nonResourceURLs:
              - /swaggerapi
              verbs:
              - get
          )
      end

      before :each do
        expect(YAML).to receive(:load_file).with(anything) { YAML.load(example_roles) }
        allow(subject).to receive(:add_node).with(anything, anything, anything)
        allow(subject).to receive(:add_relation).with(anything, anything, anything)
      end

      after :each do
        subject.send(:index_roles, "some_path_to_roles_yaml")
      end

      it 'index a new role' do
        expect(subject).to receive(:add_node).with(:Role, expected_role_label, 
          %Q({name: "#{role_name}", kind: 'Role', defined: true}))
      end

      it 'index a new namespace' do
        expect(subject).to receive(:add_node).with(:Namespace, expected_namespace_label, 
          %Q({name: "#{namespace}"}))
      end

      it 'index a relationship between a role and a namespace' do
        expect(subject).to receive(:add_relation).with(expected_role_label, :SCOPE, expected_namespace_label)
      end

      context 'with regular access rule' do
        # see process_resource_rule for details on how rule gets processed
        let(:expected_first_rule_label) { subject.send(:make_label, :resource, :core, '*', :configmaps) }

        it 'index an acces permission rule' do 
          expect(subject).to receive(:add_node).with(:Rule, expected_first_rule_label, 
            %Q({type: 'resource', api_group: 'core', verb: '*', resource: 'configmaps'}))
        end

        it 'index relationship between a role and access permission rule' do
          expect(subject).to receive(:add_relation).with(expected_role_label, :GRANT, expected_first_rule_label)
        end
      end

      context 'with resource specific access rule' do
        # see process_resource_rule for details on how rule gets processed
        let(:expected_second_rule_label) { subject.send(:make_label, :resource, :policy, :use, :podsecuritypolicies, :privileged) }

        it 'index an acces permission rule' do
          expect(subject).to receive(:add_node).with(:Rule, expected_second_rule_label, 
            %Q({type: 'resource', api_group: 'policy', verb: 'use', resource: 'podsecuritypolicies', resource_name: 'privileged'}))
        end

        it 'index relationship between a role and access permission rule' do
          expect(subject).to receive(:add_relation).with(expected_role_label, :GRANT, expected_second_rule_label)
        end
      end

      context 'with psp specific access rule' do
        # see process_resource_rule for details on how rule gets processed
        let(:expected_second_rule_label) { subject.send(:make_label, :resource, :policy, :use, :podsecuritypolicies, :privileged) }
        let(:expected_psp_label) { subject.send(:make_label, :psp, :privileged) }

        it 'index relationship between an access permission rule and psp policy' do
          expect(subject).to receive(:add_relation).with(expected_second_rule_label, :SECURITY, expected_psp_label)
        end
      end

      context 'with non-resource specific access rule' do
        # see process_non_resource_rule for details on how rule gets processed
        let(:expected_third_rule_label) { subject.send(:make_label, 'non-resource', '/swaggerapi', :get) }

        it 'index an acces permission rule' do
          expect(subject).to receive(:add_node).with(:Rule, expected_third_rule_label, 
            %Q({type: 'non-resource', url: '/swaggerapi', verb: 'get'}))
        end

        it 'index relationship between a role and access permission rule' do
          expect(subject).to receive(:add_relation).with(expected_role_label, :GRANT, expected_third_rule_label)
        end
      end
    end

    describe '#index_cluster_roles' do
      let(:cluster_role_name) { 'some:cluster-role-name' }
      let(:expected_cluster_role_label) { subject.send(:make_label, :clusterrole, cluster_role_name) }
      let(:example_cluster_roles) do
        %Q(
          apiVersion: v1
          items:
          - apiVersion: rbac.authorization.k8s.io/v1
            kind: ClusterRole
            metadata:
              name: #{cluster_role_name}
              namespace: ""
            rules:
            - apiGroups:
              - extensions
              resources:
              - ingresses
              verbs:
              - get
              - list
              - watch
            - apiGroups:
              - policy
              resourceNames:
              - privileged
              resources:
              - podsecuritypolicies
              verbs:
              - use
            - nonResourceURLs:
              - '*'
              verbs:
              - get
              - list
              - watch
        )
      end

      before :each do
        expect(YAML).to receive(:load_file).with(anything) { YAML.load(example_cluster_roles) }
        allow(subject).to receive(:add_node).with(anything, anything, anything)
        allow(subject).to receive(:add_relation).with(anything, anything, anything)
      end

      after :each do
        subject.send(:index_cluster_roles, "some_path_to_cluster_roles_yaml")
      end

      it 'index a new cluster role' do
        expect(subject).to receive(:add_node).with(:Role, expected_cluster_role_label, 
          %Q({name: "#{cluster_role_name}", kind: 'ClusterRole', defined: true}))
      end

      context 'with regular access rule' do
        # see process_resource_rule for details on how rule gets processed
        let(:expected_first_rule_label_get) { subject.send(:make_label, :resource, :extensions, :get, :ingresses) }
        let(:expected_first_rule_label_list) { subject.send(:make_label, :resource, :extensions, :list, :ingresses) }
        let(:expected_first_rule_label_watch) { subject.send(:make_label, :resource, :extensions, :watch, :ingresses) }

        it 'index an acces permission rule' do 
          expect(subject).to receive(:add_node).with(:Rule, expected_first_rule_label_get, 
            %Q({type: 'resource', api_group: 'extensions', verb: 'get', resource: 'ingresses'}))
          expect(subject).to receive(:add_node).with(:Rule, expected_first_rule_label_list, 
            %Q({type: 'resource', api_group: 'extensions', verb: 'list', resource: 'ingresses'}))
          expect(subject).to receive(:add_node).with(:Rule, expected_first_rule_label_watch, 
            %Q({type: 'resource', api_group: 'extensions', verb: 'watch', resource: 'ingresses'}))
        end

        it 'index relationship between a role and access permission rule' do
          expect(subject).to receive(:add_relation).with(expected_cluster_role_label, :GRANT, expected_first_rule_label_get)
          expect(subject).to receive(:add_relation).with(expected_cluster_role_label, :GRANT, expected_first_rule_label_list)
          expect(subject).to receive(:add_relation).with(expected_cluster_role_label, :GRANT, expected_first_rule_label_watch)
        end
      end

      context 'with resource specific access rule' do
        # see process_resource_rule for details on how rule gets processed
        let(:expected_second_rule_label) { subject.send(:make_label, :resource, :policy, :use, :podsecuritypolicies, :privileged) }

        it 'index an acces permission rule' do
          expect(subject).to receive(:add_node).with(:Rule, expected_second_rule_label, 
            %Q({type: 'resource', api_group: 'policy', verb: 'use', resource: 'podsecuritypolicies', resource_name: 'privileged'}))
        end

        it 'index relationship between a role and access permission rule' do
          expect(subject).to receive(:add_relation).with(expected_cluster_role_label, :GRANT, expected_second_rule_label)
        end
      end

      context 'with psp specific access rule' do
        # see process_resource_rule for details on how rule gets processed
        let(:expected_second_rule_label) { subject.send(:make_label, :resource, :policy, :use, :podsecuritypolicies, :privileged) }
        let(:expected_psp_label) { subject.send(:make_label, :psp, :privileged) }

        it 'index relationship between an access permission rule and psp policy' do
          expect(subject).to receive(:add_relation).with(expected_second_rule_label, :SECURITY, expected_psp_label)
        end
      end

      context 'with non-resource specific access rule' do
        # see process_non_resource_rule for details on how rule gets processed
        let(:expected_third_rule_label_get) { subject.send(:make_label, 'non-resource', '*', :get) }
        let(:expected_third_rule_label_list) { subject.send(:make_label, 'non-resource', '*', :list) }
        let(:expected_third_rule_label_watch) { subject.send(:make_label, 'non-resource', '*', :watch) }

        it 'index an acces permission rule' do
          expect(subject).to receive(:add_node).with(:Rule, expected_third_rule_label_get, 
            %Q({type: 'non-resource', url: '*', verb: 'get'}))
          expect(subject).to receive(:add_node).with(:Rule, expected_third_rule_label_list, 
            %Q({type: 'non-resource', url: '*', verb: 'list'}))
          expect(subject).to receive(:add_node).with(:Rule, expected_third_rule_label_watch, 
            %Q({type: 'non-resource', url: '*', verb: 'watch'}))
        end

        it 'index relationship between a role and access permission rule' do
          expect(subject).to receive(:add_relation).with(expected_cluster_role_label, :GRANT, expected_third_rule_label_get)
          expect(subject).to receive(:add_relation).with(expected_cluster_role_label, :GRANT, expected_third_rule_label_list)
          expect(subject).to receive(:add_relation).with(expected_cluster_role_label, :GRANT, expected_third_rule_label_watch)
        end
      end
    end

    describe '#index_role_bindings' do
      let(:role_binding_name) { 'some:role-binding-name' }
      let(:expected_role_binding_label) { subject.send(:make_label, :rolebinding, role_binding_name) }
      let(:namespace) { 'some-namespace' }
      let(:expected_namespace_label) { subject.send(:make_label, namespace) }
      let(:actor_kind) { 'ServiceAccount' }
      let(:actor_name) { 'some-actor' }
      let(:actor_namespace) { namespace }
      let(:another_actor_kind) { 'Group' }
      let(:another_actor_name) { 'some-group-actor' }
      let(:another_actor_namespace) { namespace }
      let(:ref_role_kind) { 'Role' }
      let(:ref_role_name) { 'referenced-role-name' }
      let(:expected_ref_role_label) { subject.send(:make_label, ref_role_kind, ref_role_name) }

      let(:example_role_bindings) do
        %Q(
          apiVersion: v1
          items:
          - apiVersion: rbac.authorization.k8s.io/v1
            kind: RoleBinding
            metadata:
              name: #{role_binding_name}
              namespace: #{namespace}
            roleRef:
              apiGroup: rbac.authorization.k8s.io
              kind: #{ref_role_kind}
              name: #{ref_role_name}
            subjects:
            - kind: #{actor_kind}
              name: #{actor_name}
              namespace: #{actor_namespace}
            - kind: #{another_actor_kind}
              name: #{another_actor_name}
              namespace: #{another_actor_namespace}
        )
      end

      before :each do
        expect(YAML).to receive(:load_file).with(anything) { YAML.load(example_role_bindings) }
        allow(subject).to receive(:add_node).with(anything, anything, anything)
        allow(subject).to receive(:add_relation).with(anything, anything, anything)
      end

      after :each do
        subject.send(:index_role_bindings, "some_path_to_role_bindings_yaml")
      end

      it 'index a new binding node' do
        expect(subject).to receive(:add_node).with(:Binding, expected_role_binding_label, 
          %Q({name: "#{role_binding_name}", kind: 'RoleBinding'}))
      end

      it 'index a new namespace node' do
        expect(subject).to receive(:add_node).with(:Namespace, expected_namespace_label, 
          %Q({name: "#{namespace}"}))
      end

      it 'index a relationship between a role binding and a namespace' do
        expect(subject).to receive(:add_relation).with(expected_role_binding_label, :SCOPE, expected_namespace_label)
      end

      it 'index a relationship between a role binding and a referenced role' do
        expect(subject).to receive(:add_relation).with(expected_role_binding_label, :REFERENCE, expected_ref_role_label)
      end

      context 'with Subjects' do
        context 'with namespace defined at actor (Subject) level' do
          let(:actor_namespace) { 'actor-level-specpace' }
          let(:expected_actor_label) { subject.send(:make_label, actor_name, actor_kind, actor_namespace) }

          it 'index a new subject node' do
            expect(subject).to receive(:add_node).with(:Subject, expected_actor_label, 
              %Q({name: "#{actor_name}", kind: "#{actor_kind}", namespace: "#{actor_namespace}"}))
          end

          it 'index a relationship between a role binding and a subject' do
            expect(subject).to receive(:add_relation).with(expected_role_binding_label, :SUBJECT, expected_actor_label)
          end

          it 'index a relationship between a referenced role and a subject' do
            expect(subject).to receive(:add_relation).with(expected_ref_role_label, :ASSIGN, expected_actor_label)
          end
        end

        context 'with namespace defined at role binding level' do
          let(:actor_namespace) { nil }
          let(:expected_actor_label) { subject.send(:make_label, actor_name, actor_kind, namespace) }

          it 'index a new subject node' do
            expect(subject).to receive(:add_node).with(:Subject, expected_actor_label, 
              %Q({name: "#{actor_name}", kind: "#{actor_kind}", namespace: "#{namespace}"}))
          end

          it 'index a relationship between a role binding and a subject' do
            expect(subject).to receive(:add_relation).with(expected_role_binding_label, :SUBJECT, expected_actor_label)
          end

          it 'index a relationship between a referenced role and a subject' do
            expect(subject).to receive(:add_relation).with(expected_ref_role_label, :ASSIGN, expected_actor_label)
          end
        end

        context 'with namespace defined at role level' do
          let(:namespace) { nil }
          let(:actor_namespace) { nil }
          let(:role_level_namespace) { 'role-level-namespace' }
          let(:expected_actor_label) { subject.send(:make_label, actor_name, actor_kind, role_level_namespace) }

          before :each do
            allow(subject.instance_variable_get(:@role_ns_lookup)).to receive(:fetch).with(expected_ref_role_label, nil) { role_level_namespace }
          end

          it 'index a new subject node' do
            expect(subject).to receive(:add_node).with(:Subject, expected_actor_label, 
              %Q({name: "#{actor_name}", kind: "#{actor_kind}", namespace: "#{role_level_namespace}"}))
          end

          it 'index a relationship between a role binding and a subject' do
            expect(subject).to receive(:add_relation).with(expected_role_binding_label, :SUBJECT, expected_actor_label)
          end

          it 'index a relationship between a referenced role and a subject' do
            expect(subject).to receive(:add_relation).with(expected_ref_role_label, :ASSIGN, expected_actor_label)
          end
        end

        context 'with multiple actors (Subjects)' do
          let(:expected_actor_label) { subject.send(:make_label, actor_name, actor_kind, actor_namespace) }
          let(:expected_another_actor_label) { subject.send(:make_label, another_actor_name, another_actor_kind, another_actor_namespace) }

          it 'index relationship between pairs of subjects' do
            expect(subject).to receive(:add_relation).with(expected_actor_label, :RELATION, expected_another_actor_label)
          end
        end
      end
    end

    describe '#index_cluster_role_bindings' do
      let(:cluster_role_binding_name) { 'some:role-binding-name' }
      let(:expected_cluster_role_binding_label) { subject.send(:make_label, :clusterrolebinding, cluster_role_binding_name) }
      let(:actor_kind) { 'ServiceAccount' }
      let(:actor_name) { 'some-actor' }
      let(:actor_namespace) { 'actor-level-specpace' }
      let(:another_actor_kind) { 'Group' }
      let(:another_actor_name) { 'some-group-actor' }
      let(:another_actor_namespace) { actor_namespace }
      let(:ref_role_kind) { 'ClusterRole' }
      let(:ref_role_name) { 'referenced-cluster-role-name' }
      let(:expected_ref_role_label) { subject.send(:make_label, ref_role_kind, ref_role_name) }

      let(:example_cluster_role_bindings) do
        %Q(
          apiVersion: v1
          items:
          - apiVersion: rbac.authorization.k8s.io/v1
            kind: ClusterRoleBinding
            metadata:
              name: #{cluster_role_binding_name}
              namespace: ""
            roleRef:
              apiGroup: rbac.authorization.k8s.io
              kind: #{ref_role_kind}
              name: #{ref_role_name}
            subjects:
            - kind: #{actor_kind}
              name: #{actor_name}
              namespace: #{actor_namespace}
            - kind: #{another_actor_kind}
              name: #{another_actor_name}
              namespace: #{another_actor_namespace}
        )
      end

      before :each do
        expect(YAML).to receive(:load_file).with(anything) { YAML.load(example_cluster_role_bindings) }
        allow(subject).to receive(:add_node).with(anything, anything, anything)
        allow(subject).to receive(:add_relation).with(anything, anything, anything)
      end

      after :each do
        subject.send(:index_cluster_role_bindings, "some_path_to_cluster_role_bindings_yaml")
      end

      it 'index a new binding node' do
        expect(subject).to receive(:add_node).with(:Binding, expected_cluster_role_binding_label, 
          %Q({name: "#{cluster_role_binding_name}", kind: 'ClusterRoleBinding'}))
      end

      it 'index a relationship between a cluster role binding and a referenced role' do
        expect(subject).to receive(:add_relation).with(expected_cluster_role_binding_label, :REFERENCE, expected_ref_role_label)
      end

      context 'with Subjects' do
        context 'with namespace defined at actor (Subject) level' do
          let(:actor_namespace) { 'actor-level-specpace' }
          let(:expected_actor_label) { subject.send(:make_label, actor_name, actor_kind, actor_namespace) }

          it 'index a new subject node' do
            expect(subject).to receive(:add_node).with(:Subject, expected_actor_label, 
              %Q({name: "#{actor_name}", kind: "#{actor_kind}", namespace: "#{actor_namespace}"}))
          end

          it 'index a relationship between a role binding and a subject' do
            expect(subject).to receive(:add_relation).with(expected_cluster_role_binding_label, :SUBJECT, expected_actor_label)
          end

          it 'index a relationship between a referenced role and a subject' do
            expect(subject).to receive(:add_relation).with(expected_ref_role_label, :ASSIGN, expected_actor_label)
          end
        end

        context 'with multiple actors (Subjects)' do
          let(:actor_label) { subject.send(:make_label, actor_name, actor_kind, actor_namespace) }
          let(:another_actor_label) { subject.send(:make_label, another_actor_name, another_actor_kind, another_actor_namespace) }

          it 'index relationship between pairs of subjects' do
            expect(subject).to receive(:add_relation).with(actor_label, :RELATION, another_actor_label)
          end
        end
      end
    end

    describe '#set_relation_between_two_subjects' do
      let(:a) { {name: :a, kind: 'ServiceAccount', namespace: :ns_a}.with_indifferent_access }
      let(:b) { {name: :b, kind: 'Group', namespace: :ns_b}.with_indifferent_access }

      let(:expected_a_label) { subject.send(:make_label, :a, 'ServiceAccount', :ns_a) }
      let(:expected_b_label) { subject.send(:make_label, :b, 'Group', :ns_b) }

      it 'sets relationship between any two subjects' do
        expect(subject).to receive(:add_relation).with(expected_a_label, :RELATION, expected_b_label)
        subject.send(:set_relation_between_two_subjects, a, b)
      end
    end

    describe '#set_subject_relations' do
      let(:actor_namespace) { 'ns_a' }
      let(:actor) { {name: :a, kind: 'ServiceAccount', namespace: actor_namespace}.with_indifferent_access }
      let(:role_or_cluster_role_binding_label) { 'role_or_cluster_role_binding_label' }
      let(:role_or_cluster_role_label) { 'role_or_cluster_role_label' }
      let(:binding_namespace) { nil }

      before :each do
        allow(subject).to receive(:add_relation).with(anything, anything, anything)
      end

      after :each do
        subject.send(:set_subject_relations, actor, role_or_cluster_role_binding_label, 
          role_or_cluster_role_label, binding_namespace)
      end

      context 'with namespace defined at role (Subject) level' do
        let(:expected_actor_label) { subject.send(:make_label, actor[:name], actor[:kind], actor_namespace) }

        it 'index a new subject node' do
          expect(subject).to receive(:add_node).with(:Subject, expected_actor_label, 
              %Q({name: "#{actor[:name]}", kind: "#{actor[:kind]}", namespace: "#{actor[:namespace]}"}))
        end

        it 'index a relationship between role/clusterrole binding and the subject' do
          expect(subject).to receive(:add_relation).with(role_or_cluster_role_binding_label, :SUBJECT, expected_actor_label)
        end

        it 'index a relationship between role/clusterrole and the subject' do
          expect(subject).to receive(:add_relation).with(role_or_cluster_role_label, :ASSIGN, expected_actor_label)
        end
      end

      context 'with namespace defined at role/clusterrole binding level' do
        let(:actor_namespace) { nil }
        let(:binding_namespace) { 'binding-level-namespace' }
        let(:expected_actor_label) { subject.send(:make_label, actor[:name], actor[:kind], binding_namespace) }
        
        it 'index a new subject node' do
          expect(subject).to receive(:add_node).with(:Subject, expected_actor_label, 
              %Q({name: "#{actor[:name]}", kind: "#{actor[:kind]}", namespace: "#{binding_namespace}"}))
        end

        it 'index a relationship between role/clusterrole binding and the subject' do
          expect(subject).to receive(:add_relation).with(role_or_cluster_role_binding_label, :SUBJECT, expected_actor_label)
        end

        it 'index a relationship between role/clusterrole and the subject' do
          expect(subject).to receive(:add_relation).with(role_or_cluster_role_label, :ASSIGN, expected_actor_label)
        end
      end
    end

    describe '#link_psp_rule' do
      let(:rule_label) { 'some-rule-label' }
      let(:rule) { {resource: 'podsecuritypolicies', resource_name: 'privileged'} }
      let(:expected_psp_label) { subject.send(:make_label, :psp, 'privileged') }

      it 'index relationship between PodSecurityPolicy and a access permission rule' do
        expect(subject).to receive(:add_relation).with(rule_label, :SECURITY, expected_psp_label)
        subject.send(:link_psp_rule, rule_label, rule)
      end
    end

    describe '#process_rule' do
      after :each do
        subject.send(:process_rule, rule)
      end

      context 'with resource specific rule' do
        let(:rule) { {apiGroups: '*'}.with_indifferent_access }

        it 'calls resource rule processor' do
          expect(subject).to receive(:process_resource_rule).with(rule)
        end
      end

      context 'with non-resource rule' do
        let(:rule) { {nonResourceURLs: '*'}.with_indifferent_access }

        it 'calls non-resource rule processor' do
          expect(subject).to receive(:process_non_resource_rule).with(rule)
        end
      end
    end

    describe '#process_resource_rule' do
      context 'without specific resource name' do
        let(:rule) do 
          {
            apiGroups: [''],
            resources: ['configmaps', 'pods'],
            verbs: ['get', 'update']
          }.with_indifferent_access
        end

        it 'transforms rule to array of hashes' do
          res = subject.send(:process_resource_rule, rule)
          expect(res.size).to eq 4
          expect(res).to include({type: 'resource', api_group: 'core', verb: 'get', resource: 'configmaps'})
          expect(res).to include({type: 'resource', api_group: 'core', verb: 'update', resource: 'configmaps'})
          expect(res).to include({type: 'resource', api_group: 'core', verb: 'get', resource: 'pods'})
          expect(res).to include({type: 'resource', api_group: 'core', verb: 'update', resource: 'pods'})
        end
      end

      context 'with specific resource name' do
        let(:rule) do 
          {
            apiGroups: [''],
            resourceNames: ['some-resource-name'],
            resources: ['configmaps'],
            verbs: ['get', 'update']
          }.with_indifferent_access
        end

        it 'appends resource_name to the hash' do
          res = subject.send(:process_resource_rule, rule)
          expect(res.size).to eq 2
          expect(res).to include({type: 'resource', api_group: 'core', verb: 'get', resource: 'configmaps', resource_name: 'some-resource-name'})
          expect(res).to include({type: 'resource', api_group: 'core', verb: 'update', resource: 'configmaps', resource_name: 'some-resource-name'})
        end
      end
    end

    describe '#process_non_resource_rule' do
      let(:rule) do 
        {
          nonResourceURLs: ['*'],
          verbs: ['get', 'list', 'watch']
        }.with_indifferent_access
      end

      it 'transforms rule to array of hashes' do
        res = subject.send(:process_non_resource_rule, rule)
        expect(res.size).to eq 3
        expect(res).to include({type: 'non-resource', url: '*', verb: 'get'})
        expect(res).to include({type: 'non-resource', url: '*', verb: 'list'})
        expect(res).to include({type: 'non-resource', url: '*', verb: 'watch'})
      end
    end

    describe '#make_label' do
      let(:str) { 'Hello # World' }

      it 'normalises the string by replacing non alphanumeric characters with underscores' do
        expect(subject.send(:make_label, str)).to eq 'hello___world'
      end
    end

  end

end
