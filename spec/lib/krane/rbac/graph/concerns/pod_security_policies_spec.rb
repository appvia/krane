RSpec.describe Krane::Rbac::Graph::Concerns::PodSecurityPolicies do

  # testing with builder using this concern
  subject { Krane::Rbac::Graph::Builder.new path: path, options: OpenStruct.new(verbose: false) }

  let(:path) { '/some-path' }

  let(:psp) { build(:psp) }

  let(:items_hash) do
    {
      kind:       'PodSecurityPolicyList',
      apiVersion: 'policy/v1beta1',
      metadata: {
        selfLink:        '/apis/policy/v1beta1/podsecuritypolicies',
        resourceVersion: '276683100'
      },
      items: [ psp ]
    }.with_indifferent_access
  end

  before do
    allow(YAML).to receive(:load_file).with("#{path}/psp") { items_hash }
  end

  describe '#psp' do

    it 'builds Psp node with correct attributes and adds it to the graph node buffer' do

      expected_node_attrs = {
        name:                     psp[:metadata][:name],
        privileged:               psp[:spec][:privileged],
        allowPrivilegeEscalation: psp[:spec][:allowPrivilegeEscalation],
        hostIPC:                  psp[:spec][:hostIPC],
        hostIPD:                  psp[:spec][:hostIPD],
        hostNetwork:              psp[:spec][:hostNetwork],
        fsGroup:                  psp[:spec][:fsGroup][:rule],
        runAsUser:                psp[:spec][:runAsUser][:rule],
        seLinux:                  psp[:spec][:seLinux][:rule],
        supplementalGroups:       psp[:spec][:supplementalGroups][:rule],
        allowedCapabilities:      psp[:spec][:allowedCapabilities].join(','),
        volumes:                  psp[:spec][:volumes].join(','),
        version:                  psp[:metadata][:resourceVersion],
        created_at:               psp[:metadata][:creationTimestamp],
      }

      subject.psp

      node = subject.instance_variable_get(:@node_buffer).first

      expect(node.kind).to  eq :Psp
      expect(node.label).to eq "#{Krane::Rbac::Graph::Builder::NODE_LABEL_PREFIX}1"
      expect(node.attrs).to include(expected_node_attrs)
    end

  end

end
