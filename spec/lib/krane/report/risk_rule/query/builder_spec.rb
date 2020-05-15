RSpec.describe Krane::Report::RiskRule::Query::Builder do

  describe '#for' do

    subject { described_class }

    let(:tpl) { double }

    before do
      @item = risk.instance_variable_get(:@default)[:rules].first
      allow(tpl).to receive(:query)
    end

    context 'for templates based query with match rules specified' do

      let(:risk) do 
        build(
          :risk, :with_default_template_based_rule,
          default_rule_match_rules: [
            {
              apiGroups: ['rbac.authorization.k8s.io'],
              resources: ['rolebindings'],
              verbs: ['create'],
            },
            {
              apiGroups: ['rbac.authorization.k8s.io'],
              resources: ['clusterroles'],
              verbs: ['bind'],
            }
          ]
        )
      end

      let(:expected_matches) do
        [
        "MATCH (ns:Namespace)<-[:SCOPE]-(ro0:Role {is_default: 'false'})<-[:GRANT]-(:Rule {type: 'resource', api_group: 'rbac.authorization.k8s.io', resource: 'rolebindings', verb: 'create'})",
        "MATCH (ns:Namespace)<-[:SCOPE]-(ro1:Role {is_default: 'false'})<-[:GRANT]-(:Rule {type: 'resource', api_group: 'rbac.authorization.k8s.io', resource: 'clusterroles', verb: 'bind'})"
        ].join("\n")
      end

      let(:expected_where) do
        %Q(ID(ro0) = ID(ro1))
      end

      it 'will get query for given template name with correct match rules and where conditions' do
        expect(Krane::Report::RiskRule::Query::Template)
          .to receive(:for)
          .with(
            kind: @item[:template], 
            matches: expected_matches, 
            where: expected_where
          ) { tpl }

        subject.for(item: @item)
      end

    end

    context 'for templates based query without match rules' do

      let(:risk) do 
        build(
          :risk, :with_default_template_based_rule,
          default_rule_match_rules: nil
        )
      end

      it 'will get query for given template name without pass matches and where conditions' do
        expect(Krane::Report::RiskRule::Query::Template)
          .to receive(:for).with(kind: @item[:template]) { tpl }

        subject.for(item: @item)
      end

    end

  end

end
