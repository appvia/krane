RSpec.describe Krane::Report::RiskRule::Query::RuleSelector do

  describe '#selectors' do

    subject { described_class.new(attrs) }

    context 'for resource specific rules' do

      # API groups are alternatives: a role rule names one API group per resource, so a selector
      # per group would build a query no role can satisfy. They stay on the selector as a list.
      context 'with apiGroups specified' do

        let(:attrs) do
          {
            apiGroups: ['g1', 'g2'],
            resources: ['r1']
          }
        end

        it 'returns expected array of selectors hashes' do
          expect(subject.selectors).to eq(
            [{:type=>"resource", :api_groups=>["g1", "g2", "*"], :resource=>"r1"}]
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
            {:type=>"resource", :api_groups=>["g1", "g2", "*"], :resource=>"r1", :verb=>"get"},
            {:type=>"resource", :api_groups=>["g1", "g2", "*"], :resource=>"r1", :verb=>"list"}
          )
        end

      end

      context 'with the core apiGroup specified' do

        let(:attrs) do
          {
            apiGroups: [''],
            resources: ['secrets']
          }
        end

        it 'matches the `core` group the graph stores for it' do
          expect(subject.selectors).to eq(
            [{:type=>"resource", :api_groups=>["core", "*"], :resource=>"secrets"}]
          )
        end

      end

      context 'with the wildcard apiGroup specified' do

        let(:attrs) do
          {
            apiGroups: ['*'],
            resources: ['*']
          }
        end

        it 'matches the wildcard group only' do
          expect(subject.selectors).to eq(
            [{:type=>"resource", :api_groups=>["*"], :resource=>"*"}]
          )
        end

      end

      context 'without apiGroups specified' do

        let(:attrs) do
          {
            resources: ['r1'],
            verbs: ['get']
          }
        end

        it 'leaves the API group unconstrained' do
          expect(subject.selectors).to eq(
            [{:type=>"resource", :resource=>"r1", :verb=>"get"}]
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
