RSpec.describe Krane::Report::RiskRule::Query::RuleSelector do

  describe '#selectors' do

    subject { described_class.new(attrs) }

    context 'for resource specific rules' do

      context 'with apiGroups specified' do

        let(:attrs) do
          {
            apiGroups: ['g1', 'g2'],
            resources: ['r1']
          }
        end

        it 'returns expected array of selectors hashes' do
          expect(subject.selectors).to include(
            {:api_group=>"g1", :resource=>"r1", :type=>"resource"},
            {:api_group=>"g2", :resource=>"r1", :type=>"resource"}
          )
        end

      end

      context 'with apiGroups and verbs specified' do
        let(:attrs) do
          {
            apiGroups: ['g1', 'g2'],
            resources: ['r1'],
            verbs: ['get', 'list']
          }
        end

        it 'returns expected array of selectors hashes' do
          expect(subject.selectors).to include(
            {:api_group=>"g1", :resource=>"r1", :type=>"resource", :verb=>"get"},
            {:api_group=>"g1", :resource=>"r1", :type=>"resource", :verb=>"list"},
            {:api_group=>"g2", :resource=>"r1", :type=>"resource", :verb=>"get"},
            {:api_group=>"g2", :resource=>"r1", :type=>"resource", :verb=>"list"}
          )
        end

      end

    end

    context 'for non-resource URL rules' do

      context 'with nonResourceURLs specified' do

        let(:attrs) do
          {
            nonResourceURLs: ['u1', 'u2']
          }
        end

        it 'returns expected array of selectors hashes' do
          expect(subject.selectors).to include(
            {:type=>"non-resource", :url=>"u1"}, 
            {:type=>"non-resource", :url=>"u2"}
          )
        end

      end

      context 'with nonResourceURLs and verbs specified' do

        let(:attrs) do
          {
            nonResourceURLs: ['u1', 'u2'],
            verbs: ['get', 'list']
          }
        end

        it 'returns expected array of selectors hashes' do
          expect(subject.selectors).to include(
            {:type=>"non-resource", :url=>"u1", :verb=>"get"},
            {:type=>"non-resource", :url=>"u1", :verb=>"list"},
            {:type=>"non-resource", :url=>"u2", :verb=>"get"},
            {:type=>"non-resource", :url=>"u2", :verb=>"list"}          
          )
        end

      end 

    end

  end

end
