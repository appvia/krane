RSpec.describe Krane::Report::RiskRule::Resolver do

  describe '#risk_rules' do

    let(:cluster)   { :default }
    let(:risk)      { build(:risk) }
    let(:whitelist) { build(:whitelist) }

    subject { described_class.new(cluster: cluster, risk: risk, whitelist: whitelist) }

    context 'with query based risk rule' do

      let(:risk) { build(:risk, :with_default_query_based_rule) }

      it 'resolves each defined risk rule to canonical representation' do
        risk_rule = risk.instance_variable_get(:@default)[:rules].first.dup

        res = subject.risk_rules

        expect(res.first.class).to be Krane::Report::RiskRule::Item
        expect(res.first.query).not_to be_nil
        expect(res.first.writer).not_to be_nil
        expect(res.first).to include(
          id:          risk_rule[:id],
          severity:    risk_rule[:severity],
          group_title: risk_rule[:group_title],
          info:        risk_rule[:info],
          query:       risk_rule[:query],
          writer:      risk_rule[:writer],
          disabled:    risk_rule[:disabled]
        )
      end

    end

    context 'with template based risk rule' do

      context 'for invalid template name' do

        let(:invalid_template_name) { 'invalid' }
        let(:risk) do
          build(
            :risk, 
            :with_default_template_based_rule, 
            default_rule_template: invalid_template_name
          )
        end

        it 'raises an exception' do
          expect { subject.risk_rules }.to raise_exception(
            Krane::Report::RiskRule::Query::Template::UnknownTemplate, 
            "Undefined template `#{invalid_template_name}` referenced in the risk rules configuration"
          )
        end

      end

      context 'for valid template name' do

        let(:valid_template_name) { 'test_template' }

        let(:risk) do
          build(
            :risk, 
            :with_default_template_based_rule, 
            default_rule_template: valid_template_name
          )
        end

        before do
          # injecting template for test
          module Krane::Report::RiskRule::Query::Template
            def test_template
              OpenStruct.new(query: 'Test Query', writer: 'Test Writer')
            end
          end
        end

        it 'resolves each defined risk rule to canonical representation' do
          @risk_rule = risk.instance_variable_get(:@default)[:rules].first.dup

          expect(@risk_rule[:template]).not_to be_nil
          expect(@risk_rule[:query]).to be_nil
          expect(@risk_rule[:writer]).to be_nil

          res = subject.risk_rules

          expect(res.first.class).to be Krane::Report::RiskRule::Item
          expect(res.first.query).not_to be_nil
          expect(res.first.writer).not_to be_nil
          expect(res.first).to include(
            id:          @risk_rule[:id],
            severity:    @risk_rule[:severity],
            group_title: @risk_rule[:group_title],
            info:        @risk_rule[:info],
            query:       'Test Query',
            writer:      'Test Writer',
            disabled:    @risk_rule[:disabled]
          )
        end

      end

    end

    context 'with query based risk rule without both query & writer specified' do

      let(:risk) do
        build(:risk, :with_default_query_based_rule, default_rule_query: nil)
      end

      it 'raises an exception' do
        expect { subject.risk_rules }.to raise_exception(
          Krane::Report::RiskRule::Resolver::RuleConfigError, 
          "rule-id - must define `query`&`writer` OR `template` fields!")
      end

    end

    context 'with templates based risk rule without template name specified' do

      let(:risk) do
        build(:risk, :with_default_template_based_rule, default_rule_template: nil)
      end

      it 'raises an exception' do
        expect { subject.risk_rules }.to raise_exception(
          Krane::Report::RiskRule::Resolver::RuleConfigError,
          "rule-id - must define `query`&`writer` OR `template` fields!")
      end

    end

    context 'with custom params provided in the risk rule' do

      let(:custom_query_param_key)  { :query_param_1 }
      let(:custom_query_param_val)  { :query_value_1 }
      let(:custom_writer_param_key) { :writer_param_1 }
      let(:custom_writer_param_val) { :writer_value_1 }

      let(:risk) do
        build(:risk, :with_default_query_based_rule, 
          default_rule_custom_params: {
            custom_query_param_key  => custom_query_param_val,
            custom_writer_param_key => custom_writer_param_val
          },
          default_rule_query: "QUERY WITH PLACEHOLDER {{#{custom_query_param_key}}}",
          default_rule_writer: "WRITER EXPR. WITH PLACEHOLDER {{#{custom_writer_param_key}}}"
        )
      end

      it 'substitutes placeholders in query / writer with values from custom params' do
        res = subject.risk_rules
        expect(res.first.query).to eq "QUERY WITH PLACEHOLDER #{custom_query_param_val}"
        expect(res.first.writer).to eq "WRITER EXPR. WITH PLACEHOLDER #{custom_writer_param_val}"
      end

    end

    context 'with whitelist specified' do

      let(:whitelist_key)  { 'some_key' }
      let(:whitelist_vals) { ['item1', 'item2'] }

      let(:risk) do
        build(:risk, :with_default_query_based_rule,
          default_rule_query: sample_query
        )
      end

      let(:whitelist) do
        build(:whitelist, :with_global_config,
          global_whitelist_key:  whitelist_key,
          global_whitelist_vals: whitelist_vals
        )
      end

      context 'for query placeholders matching whitelist key' do

        let(:sample_query) do
          "QUERY WITH WHITELIST {{#{whitelist_key}}}"
        end

        it 'substitutes known whitelisted placeholders' do
          res = subject.risk_rules
          expect(res.first.query).to eq "QUERY WITH WHITELIST #{whitelist_vals}"
        end

      end

      context 'for query placeholders not matching any of whitelist key' do

        let(:sample_query) do
          "QUERY WITH WHITELIST {{undefined_whitelist_placeholder}}"
        end

        it 'substitutes placehoders not defined in whitelist with empty string array' do
          res = subject.risk_rules
          expect(res.first.query).to eq "QUERY WITH WHITELIST [\"\"]"
        end

      end 

    end

    context 'with threshold specified' do

      let(:threshold) { 5 }
      let(:risk) do
        build(:risk, :with_default_query_based_rule,
          default_rule_threshold: threshold,
          default_rule_writer: "WRITER EXPRESSION {{threshold}} EXAMPLE"
        )
      end

      it 'substitutes {{threshold}} placeholder in the writer expression' do
        res = subject.risk_rules
        expect(res.first.writer).to eq "WRITER EXPRESSION #{threshold} EXAMPLE"
      end

    end

  end

end
