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
            [{:type=>"resource", :api_group=>["g1", "g2", "*"], :resource=>["r1", "*"]}]
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
            {:type=>"resource", :api_group=>["g1", "g2", "*"], :resource=>["r1", "*"], :verb=>["get", "*"]},
            {:type=>"resource", :api_group=>["g1", "g2", "*"], :resource=>["r1", "*"], :verb=>["list", "*"]}
          )
        end

      end

      # Resources and verbs, unlike API groups, are matched together - a role only matches when it
      # grants all of them - so each stays on its own selector. Only the wildcard joins it there.
      context 'with several resources and verbs specified' do

        let(:attrs) do
          {
            apiGroups: ['rbac.authorization.k8s.io'],
            resources: ['rolebindings'],
            verbs: ['patch', 'get']
          }
        end

        it 'returns one selector per resource and verb combination' do
          expect(subject.selectors.size).to eq 2
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
            [{:type=>"resource", :api_group=>["core", "*"], :resource=>["secrets", "*"]}]
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
            [{:type=>"resource", :api_group=>["*"], :resource=>["*"]}]
          )
        end

      end

      # Issue #529: a role rule granting `verbs: ['*']` grants the named verb, and one granting
      # `resources: ['*']` covers the named resource, so both have to match.
      context 'with a resource and a verb named' do

        let(:attrs) do
          {
            apiGroups: ['apps'],
            resources: ['daemonsets'],
            verbs: ['create']
          }
        end

        it 'accepts the wildcard alongside each of them' do
          expect(subject.selectors).to eq(
            [{:type=>"resource", :api_group=>["apps", "*"], :resource=>["daemonsets", "*"], :verb=>["create", "*"]}]
          )
        end

      end

      context 'with the wildcard resource and verb specified' do

        let(:attrs) do
          {
            apiGroups: ['*'],
            resources: ['*'],
            verbs: ['*']
          }
        end

        it 'does not repeat the wildcard' do
          expect(subject.selectors).to eq(
            [{:type=>"resource", :api_group=>["*"], :resource=>["*"], :verb=>["*"]}]
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
            [{:type=>"resource", :resource=>["r1", "*"], :verb=>["get", "*"]}]
          )
        end

      end

    end

    context 'for non-resource URL rules' do

      # RBAC matches a non-resource URL by prefix, so `*` is only one of the patterns that can
      # cover a given URL. The URL is matched as written; the verb still accepts the wildcard.
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
            {:type=>"non-resource", :url=>"u1", :verb=>["get", "*"]},
            {:type=>"non-resource", :url=>"u1", :verb=>["list", "*"]},
            {:type=>"non-resource", :url=>"u2", :verb=>["get", "*"]},
            {:type=>"non-resource", :url=>"u2", :verb=>["list", "*"]}
          )
        end

      end 

    end

  end

end
