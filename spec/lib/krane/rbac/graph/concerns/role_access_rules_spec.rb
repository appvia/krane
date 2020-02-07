RSpec.describe Krane::Rbac::Graph::Concerns::RoleAccessRules do

  subject { Class.new.include(described_class).new }

  let(:resource_rule)     { build(:resource_rule) }
  let(:non_resource_rule) { build(:non_resource_rule) }

  describe '#process_rule' do

    context 'for resource rule' do

      it 'will call correct processor' do
        expect(subject).to receive(:process_resource_rule).with(resource_rule)
        subject.process_rule(resource_rule)
      end

    end

    context 'for non-resource rule' do

      it 'will call correct processor' do
        expect(subject).to receive(:process_non_resource_rule).with(non_resource_rule)
        subject.process_rule(non_resource_rule)
      end

    end

  end

  describe '#process_resource_rule' do

    let(:api_groups)     { [''] }
    let(:resources)      { ['configmaps'] }
    let(:resource_names) { ['my-configmap'] }
    let(:verbs)          { ['get', 'list'] }

    let(:resource_rule) do 
      build(
        :resource_rule, 
        api_groups: api_groups, 
        resources: resources, 
        verbs: verbs, 
        resource_names: resource_names
      )
    end

    it 'builds an array of kubernetes resource access rule attribute hashes for graph nodes' do
        res = subject.process_resource_rule(resource_rule)

        expect(res.size).to be 2

        expect(res).to include(
          {
            api_group:      'core', # '' is mapped to `core`
            resource:       resources.first, 
            resource_name:  resource_names.first, 
            type:           'resource', 
            verb:           verbs.first
          }
        )
        expect(res).to include(
          {
            api_group:      'core',
            resource:       resources.first, 
            resource_name:  resource_names.first, 
            type:           'resource', 
            verb:           verbs.last
          }
        )
    end

    context 'without resourceNames specified in the rule' do

      let(:resource_names) { nil }
      let(:verbs)          { ['update'] }

      it 'does not include resource name in resultant rule attributes hash' do
        res = subject.process_resource_rule(resource_rule)

        expect(res).to include(
          {
            api_group:      'core',
            resource:       resources.first, 
            type:           'resource', 
            verb:           verbs.first
          }
        )
      end

    end
    
  end

  describe '#process_non_resource_rule' do

    let(:non_resource_urls) { ['/some-url', '/healthz/*'] }
    let(:verbs)             { ['get', 'update'] }

    let(:non_resource_rule) do
      build(
        :non_resource_rule, 
        non_resource_urls: non_resource_urls,
        verbs: verbs
      )
    end

    it 'builds an array of kubernetes non-resource URL access rule attribute hashes for graph nodes' do
    
      res = subject.process_non_resource_rule(non_resource_rule)

      expect(res.size).to be 4

      expect(res).to include(
        {
          type:           'non-resource', 
          url:            non_resource_urls.first,
          verb:           verbs.first,
        }
      )
      expect(res).to include(
        {
          type:           'non-resource', 
          url:            non_resource_urls.first,
          verb:           verbs.last,
        }
      )
      expect(res).to include(
        {
          type:           'non-resource', 
          url:            non_resource_urls.last,
          verb:           verbs.first,
        }
      )
      expect(res).to include(
        {
          type:           'non-resource', 
          url:            non_resource_urls.last,
          verb:           verbs.last,
        }
      )

    end

  end

end
