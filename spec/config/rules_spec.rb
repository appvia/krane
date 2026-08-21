# Guards the rules krane actually ships, as opposed to resolver_spec.rb which drives the
# resolver with synthetic rules from a factory. Nothing else in the suite reads
# config/rules.yaml, so a rule can be edited into a shape that raises, or that silently
# stops matching, without a single example failing.

# Writers are Ruby, evaluated inside the report builder so they can reach the helpers it
# carries. This stands in for that.
class ShippedWriterContext
  include Krane::Helpers

  def evaluate writer, result # rubocop:disable Lint/UnusedMethodArgument -- the writer reads it
    eval writer
  end
end

RSpec.describe 'the shipped risk rules' do

  let(:resolved) do
    Krane::Report::RiskRule::Resolver.new(
      cluster:   :default,
      risk:      Krane::Config::Risk.new,
      whitelist: Krane::Config::Whitelist.new
    ).risk_rules
  end

  def rule id
    resolved.find { |item| item[:id] == id }
  end

  it 'resolves every enabled rule' do
    expect { resolved }.not_to raise_exception
    expect(resolved).not_to be_empty
  end

  it 'leaves no placeholder unsubstituted in a writer' do
    unsubstituted = resolved.each_with_object({}) do |item, hsh|
      found = item[:writer].to_s.scan(/{{.*?}}/)
      hsh[item[:id]] = found if found.any?
    end

    expect(unsubstituted).to be_empty
  end

  # Queries cannot be checked the same way: the whitelist step rewrites every {{...}} it does
  # not recognise to [""], so a misspelt or undefined placeholder resolves to an empty list and
  # silently widens the query rather than leaving a trace. Catch it at the source instead - each
  # placeholder a rule writes must be one the resolver has a value for.
  it 'only references placeholders the resolver can resolve' do
    unresolvable = Krane::Config::Risk.new.rules.each_with_object({}) do |rule, hsh|
      available = ['threshold'] + rule[:custom_params].to_h.keys.map(&:to_s)

      found = [rule[:query], rule[:writer]].compact.flat_map { |str| str.scan(/{{(.*?)}}/).flatten }
      # Whitelist keys are defined by the operator, so any of them may legitimately be absent.
      found = found.reject { |name| name.start_with?('whitelist_') || available.include?(name) }

      hsh[rule[:id]] = found if found.any?
    end

    expect(unresolvable).to be_empty
  end

  # Issue #80: a match rule that names no apiGroups matches a role rule naming ANY API group,
  # so a `*` resource scoped to one CRD group was reported as access to every resource, and a
  # `secrets` rule matched a CRD of the same name in an unrelated group.
  it 'scopes every match rule to the API groups its resources live in' do
    unscoped = Krane::Config::Risk.new.rules.each_with_object({}) do |rule, hsh|
      found = rule[:match_rules].to_a.reject do |match_rule|
        # Non-resource URL rules are not part of any API group.
        match_rule[:nonResourceURLs].present? || match_rule[:apiGroups].present?
      end

      hsh[rule[:id]] = found if found.any?
    end

    expect(unscoped).to be_empty
  end

  describe 'risky-any-resource-get' do

    subject { rule('risky-any-resource-get') }

    # The rule reported in issue #80. `*` resources within a single API group is what every
    # operator's own ClusterRole grants, and is not access to all resources.
    it 'only matches a rule granting the wildcard API group' do
      expect(subject[:query]).to include %q(ru0.api_group IN ['*'])
    end

  end

  describe 'risky-get-secrets' do

    subject { rule('risky-get-secrets') }

    # `''` in the rule definition, `core` in the graph - and a role rule granting every API
    # group grants the core one too.
    it 'matches a rule granting the core API group, or every API group' do
      expect(subject[:query]).to include %q(ru0.api_group IN ['core', '*'])
    end

    # Issue #529: a role granting `verbs: ['*']` on secrets, or `get` on `resources: ['*']`
    # within the core group, allows viewing secrets and used not to be matched at all.
    it 'matches a rule granting the wildcard resource, or the wildcard verb' do
      expect(subject[:query]).to include %q(ru0.resource IN ['secrets', '*'])
      expect(subject[:query]).to include %q(ru0.verb IN ['get', '*'])
    end

  end

  # Issue #529, second half. Accepting the wildcard in place of a named resource and verb means a
  # role granting everything matches every risky-role rule there is, which buries the findings a
  # reader can act on. `unrestricted-cluster-wide-subjects` and `unrestricted-ns-level-subjects`
  # report that role in the words that fit it, so the risky-role rules stop short of it.
  #
  # Only the wildcard API group is excluded. A role rule naming a group - `core` included - grants
  # nothing outside it, so the resources it does cover stay worth naming.
  it 'excludes a role rule granting unrestricted access from every resource match rule' do
    matching = Krane::Config::Risk.new.rules.select { |item| item[:match_rules].to_a.any? }

    unguarded = matching.reject do |item|
      resource_rules = item[:match_rules].count { |match_rule| match_rule[:resources].present? }
      query          = rule(item[:id])[:query]

      resource_rules.times.all? do |index|
        query.include?(
          "NOT (ru#{index}.api_group = '*' " \
          "AND ru#{index}.resource = '*' AND ru#{index}.verb = '*')"
        )
      end
    end

    expect(matching).not_to be_empty
    expect(unguarded.map { |item| item[:id] }).to be_empty
  end

  # A finding's items are marker-rendered, so `name_of(...)` becomes bold in the dashboard. Its
  # `info` is not - FindingCard.vue interpolates it as plain text - so a backtick written there
  # reaches the user as a literal character.
  it 'marks no names in rule info text' do
    marked = resolved.select { |item| item[:info].to_s.include?('`') }.map { |item| item[:id] }

    expect(marked).to be_empty
  end

  describe 'unauthenticated-subject-access' do

    subject { rule('unauthenticated-subject-access') }

    it 'is enabled and reports as a danger' do
      expect(subject).not_to be_nil
      expect(subject.disabled?).to be false
      expect(subject[:severity]).to eq :danger
    end

    it 'matches both identities the API server gives an uncredentialed request' do
      expect(subject[:query]).to include %q(s.name IN ["system:anonymous", "system:unauthenticated"])
    end

    # The crux of issue #339. Every other subject rule filters on `is_default: 'false'`, which
    # is why binding cluster-admin to system:anonymous used to report nothing at all. Adding
    # that filter here for consistency would silently reintroduce the bug, so pin its absence.
    it 'does not exclude Kubernetes default roles' do
      expect(subject[:query]).not_to include 'is_default'
    end

    it 'excludes the anonymous access a cluster legitimately ships with' do
      expect(subject[:query]).to include(
        %q(NOT ro.name IN ["system:public-info-viewer", "kubeadm:bootstrap-signer-clusterinfo"])
      )
    end

    it 'writes a finding naming the subject and the role it is bound to' do
      result = OpenStruct.new(
        subject_kind: 'User',
        subject_name: 'system:anonymous',
        role_kind:    'ClusterRole',
        role_name:    'cluster-admin'
      )

      expect(ShippedWriterContext.new.evaluate(subject[:writer], result)).to eq(
        'User `system:anonymous` is bound to ClusterRole `cluster-admin`'
      )
    end

  end

end
