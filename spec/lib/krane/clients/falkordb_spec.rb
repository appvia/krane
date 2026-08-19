RSpec.describe Krane::Clients::FalkorDB do

  subject { described_class }

  describe 'class methods' do

    describe '.client' do

      let(:graph) { described_class::Graph }

      context 'with default params' do

        it 'should return instance of Graph client with default cluster' do
          expect(graph).to receive(:new).with("rbac-default", {
            host: subject::FALKORDB_HOST,
            port: subject::FALKORDB_PORT
          })

          subject.client
        end

      end

      context 'with supplied attributes' do

        let(:attrs) do
          {
            cluster: :some_cluster,
            host:    '1.1.1.1',
            port:    '9000'
          }
        end

        it 'should return instance of Graph client' do
          expect(graph).to receive(:new).with(
            "rbac-#{attrs[:cluster]}",
            { host: attrs[:host], port: attrs[:port] }
          )

          subject.client(attrs)
        end

      end

      context 'with FALKORDB_HOST and FALKORDB_PORT set' do

        before do
          stub_const('ENV', ENV.to_h.merge('FALKORDB_HOST' => '2.2.2.2', 'FALKORDB_PORT' => '7000'))
        end

        it 'should return instance of Graph client using the environment' do
          expect(graph).to receive(:new).with("rbac-default", { host: '2.2.2.2', port: '7000' })

          subject.client
        end

      end

      context 'with the superseded REDIS_GRAPH_HOST and REDIS_GRAPH_PORT set' do

        before do
          stub_const('ENV', ENV.to_h.merge('REDIS_GRAPH_HOST' => '3.3.3.3', 'REDIS_GRAPH_PORT' => '8000'))
        end

        it 'should fall back to them so existing deployments keep working' do
          expect(graph).to receive(:new).with("rbac-default", { host: '3.3.3.3', port: '8000' })

          subject.client
        end

      end

    end

  end

end
