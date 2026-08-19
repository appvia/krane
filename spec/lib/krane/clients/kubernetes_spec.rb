RSpec.describe Krane::Clients::Kubernetes do

  subject { described_class.new(options) }

  describe '#new' do

    context 'with --incluster command line option' do

      let(:options) { OpenStruct.new(incluster: true) } # mock command line options

      before do
        allow(File).to receive(:exist?).with(described_class::CA_FILE_PATH) { true }
      end

      it 'correctly sets K8s api access parameters' do
        expect(subject.instance_variable_get(:@api_endpoint)).to eq described_class::API_ENDPOINT
        expect(subject.instance_variable_get(:@auth_options)).to include(bearer_token_file: described_class::TOKEN_FILE_PATH)
        expect(subject.instance_variable_get(:@ssl_options)).to include(ca_file: described_class::CA_FILE_PATH)
      end

    end

    context 'with --kubecontext command line option' do

      let(:options) { OpenStruct.new(kubecontext: 'minikube') } # mock command line options
      let(:env_kubecofig_path) { '/some/path' }
      let(:config)  { double }
      let(:context) do 
        double(
          api_endpoint: 'https://some-endpoint',
          auth_options: {bearer_token: 'xxxxx'},
          ssl_options:  {verify_ssl: 1}
        )
      end

      context 'when KUBECONFIG env variable defined' do

        before do
          allow(ENV).to receive(:[]).with('KUBECONFIG') { env_kubecofig_path }
          expect(File).to receive(:expand_path).never
          expect(Kubeclient::Config).to receive(:read).with(env_kubecofig_path) { config }
          expect(config).to receive(:context).with(options.kubecontext) { context }
        end

        it 'should correctly set K8s api access parameters' do
          expect(subject.instance_variable_get(:@api_endpoint)).to eq context.api_endpoint
          expect(subject.instance_variable_get(:@auth_options)).to eq context.auth_options
          expect(subject.instance_variable_get(:@ssl_options)).to eq context.ssl_options
        end

      end

      context 'when KUBECONFIG env variable is not defined' do

        let(:default_kubeconfig_path) { '~/.kube/config' }
        let(:expanded_default_kubeconfig_path) { double }

        before do
          allow(ENV).to receive(:[]).with('KUBECONFIG') { nil }
          expect(File).to receive(:expand_path).with(default_kubeconfig_path) { expanded_default_kubeconfig_path }
          expect(Kubeclient::Config).to receive(:read).with(expanded_default_kubeconfig_path) { config }
          expect(config).to receive(:context).with(options.kubecontext) { context }
        end

        it 'should correctly set K8s api access parameters' do
          expect(subject.instance_variable_get(:@api_endpoint)).to eq context.api_endpoint
          expect(subject.instance_variable_get(:@auth_options)).to eq context.auth_options
          expect(subject.instance_variable_get(:@ssl_options)).to eq context.ssl_options
        end

      end

    end

  end

  describe '#version' do

    let(:options) { OpenStruct.new(incluster: true) } # --incluster

    let(:rest_client) { double }
    let(:headers)     { { Authorization: 'Bearer xxxxx' } }
    let(:client)      { double(get_headers: headers) }

    before do
      allow(File).to receive(:exist?).with(described_class::CA_FILE_PATH) { true }
      allow(Kubeclient::Client).to receive(:new) { client }
      allow(client).to receive(:create_rest_client).with('/version') { rest_client }
    end

    it 'queries the /version endpoint with the authentication and ssl options of the cluster' do
      expect(Kubeclient::Client).to receive(:new).with(
        described_class::API_ENDPOINT, 'v1',
        auth_options: { bearer_token_file: described_class::TOKEN_FILE_PATH },
        ssl_options:  { ca_file: described_class::CA_FILE_PATH }
      ) { client }
      expect(rest_client).to receive(:get).with(headers) { '{"major":"1","minor":"32"}' }

      expect(subject.version).to eq Gem::Version.new('1.32')
    end

    it 'strips non numeric characters from the reported version' do
      allow(rest_client).to receive(:get) { '{"major":"1","minor":"32+"}' }

      expect(subject.version).to eq Gem::Version.new('1.32')
    end

    it 'raises when the api server does not return a version' do
      allow(rest_client).to receive(:get) { '{"kind":"Status","code":401,"message":"Unauthorized"}' }

      expect { subject.version }.to raise_error(ArgumentError)
    end

  end

  describe '#psp' do

    let(:options) { OpenStruct.new(incluster: true) } # --incluster

    it 'instantiates client for psp api endpoint' do
      expect(Kubeclient::Client).to receive(:new).with(
        subject.instance_variable_get(:@api_endpoint) + '/apis/policy', 'v1beta1',
        auth_options: subject.instance_variable_get(:@auth_options),
        ssl_options:  subject.instance_variable_get(:@ssl_options)
      )

      subject.psp
    end
  
  end

  describe '#rbac' do
  
    let(:options) { OpenStruct.new(incluster: true) } # --incluster

    it 'instantiates client for rbac api endpoint' do
      expect(Kubeclient::Client).to receive(:new).with(
        subject.instance_variable_get(:@api_endpoint) + '/apis/rbac.authorization.k8s.io', 'v1',
        auth_options: subject.instance_variable_get(:@auth_options),
        ssl_options:  subject.instance_variable_get(:@ssl_options)
      )

      subject.rbac
    end
  
  end

end
