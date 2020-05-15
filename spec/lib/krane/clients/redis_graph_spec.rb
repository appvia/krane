RSpec.describe Krane::Clients::RedisGraph do

  subject { described_class }

  describe 'class methods' do

    describe '.client' do

      context 'with default params' do

        it 'should return instance of RedisGraph client with default cluster' do
          expect(RedisGraph).to receive(:new).with("rbac-default", {
            host: subject::REDIS_GRAPH_HOST, 
            port: subject::REDIS_GRAPH_PORT 
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

        it 'should return instance of RedisGraph client' do
          expect(RedisGraph).to receive(:new).with(
            "rbac-#{attrs[:cluster]}",
            { host: attrs[:host], port: attrs[:port] }
          )

          subject.client(attrs)
        end

      end

    end

  end
  
end
