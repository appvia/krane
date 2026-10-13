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
        "MATCH (ns:Namespace)<-[:SCOPE]-(ro0:Role {is_default: 'false'})<-[:GRANT]-(ru0:Rule {type: 'resource'})",
        "MATCH (ns:Namespace)<-[:SCOPE]-(ro1:Role {is_default: 'false'})<-[:GRANT]-(ru1:Rule {type: 'resource'})"
        ].join("\n")
      end

      let(:expected_where) do
        %Q(ID(ro0) = ID(ro1) AND ) +
        %Q(ru0.api_group IN ['rbac.authorization.k8s.io', '*'] AND ) +
        %Q(ru0.resource IN ['rolebindings', '*'] AND ) +
        %Q(ru0.verb IN ['create', '*'] AND ) +
        %Q(ru1.api_group IN ['rbac.authorization.k8s.io', '*'] AND ) +
        %Q(ru1.resource IN ['clusterroles', '*'] AND ) +
        %Q(ru1.verb IN ['bind', '*'] AND ) +
        %Q(NOT (ru0.api_group = '*' AND ru0.resource = '*' AND ru0.verb = '*') AND ) +
        %Q(NOT (ru1.api_group = '*' AND ru1.resource = '*' AND ru1.verb = '*'))
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

    # The crux of issue #80: a role rule granting `*` resources within one API group used to be
    # matched by a rule looking for `*` resources, and so reported as access to everything.
    context 'for a match rule scoped to the wildcard API group' do

      let(:risk) do
        build(
          :risk, :with_default_template_based_rule,
          default_rule_match_rules: [
            {
              apiGroups: ['*'],
              resources: ['*'],
              verbs: ['get'],
            }
          ]
        )
      end

      it 'constrains the API group of the matched rule' do
        expect(Krane::Report::RiskRule::Query::Template)
          .to receive(:for)
          .with(
            kind: @item[:template],
            matches: "MATCH (ns:Namespace)<-[:SCOPE]-(ro0:Role {is_default: 'false'})" \
                     "<-[:GRANT]-(ru0:Rule {type: 'resource'})",
            where: %Q(ru0.api_group IN ['*'] AND ru0.resource IN ['*'] AND ru0.verb IN ['get', '*'] AND ) +
                   %Q(NOT (ru0.api_group = '*' AND ru0.resource = '*' AND ru0.verb = '*'))
          ) { tpl }

        subject.for(item: @item)
      end

    end

    # Non-resource URL rules carry no API group and no resource, so nothing about them can amount
    # to unrestricted access and the exclusion has no property to match on.
    context 'for a non-resource URL match rule' do

      let(:risk) do
        build(
          :risk, :with_default_template_based_rule,
          default_rule_match_rules: [
            {
              nonResourceURLs: ['/healthz'],
              verbs: ['get'],
            }
          ]
        )
      end

      it 'matches the URL as written and does not exclude unrestricted access' do
        expect(Krane::Report::RiskRule::Query::Template)
          .to receive(:for)
          .with(
            kind: @item[:template],
            matches: "MATCH (ns:Namespace)<-[:SCOPE]-(ro0:Role {is_default: 'false'})" \
                     "<-[:GRANT]-(ru0:Rule {type: 'non-resource', url: '/healthz'})",
            where: %Q(ru0.verb IN ['get', '*'])
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
