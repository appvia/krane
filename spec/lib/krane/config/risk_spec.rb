RSpec.describe Krane::Config::Risk do

  subject { build(:risk) }

  describe '#rules' do

    context 'with no default risk rule and custom risk rules defined' do

      subject { build(:risk, :without_any_rules) }

      it 'return nil' do
        expect(subject.rules).to be_nil
      end

    end

    context 'with undefined custom risk rules' do

      subject { build(:risk, :with_default_query_based_rule) }

      it 'returns unchanged risk rules' do
        expect(subject.rules).to eq subject.instance_variable_get(:@default)[:rules]
      end

    end

    context 'with both default and custom rules' do

      context 'for rules with the same id in default and custom set' do

        subject do
          build(:risk, :with_default_query_based_rule, :with_custom_query_based_rule, 
                default_rule_id: 'same-id', 
                custom_rule_id:  'same-id', 
                custom_rule_disabled: true)
        end

        it 'deep merges default with custom risk rules together for the same rule id' do
          # before compiling rules the first default rule should be enabled
          expect(subject.instance_variable_get(:@default)[:rules].first[:disabled]).to eq false
  
          @rules = subject.rules

          expect(@rules.size).to eq 1
          expect(@rules.first[:disabled]).to eq true
        end

      end

      context 'for different rules ids in default and custom set' do

        subject do
          build(:risk, :with_default_query_based_rule, :with_custom_query_based_rule, 
                default_rule_id: 'default-id', custom_rule_id:  'custom-id')
        end

        it 'deep merges default and custom risk rules together and returns an array' do
          @rules = subject.rules

          expect(@rules.size).to eq 2
          expect(@rules.first).to include(id: 'default-id')
          expect(@rules.last).to  include(id: 'custom-id')
        end

      end

    end

  end

  describe '#macros' do

    context 'with custom macros not defined' do

      subject { build(:risk, :with_default_macro) }

      it 'returns unchanged built-in macros' do
        expect(subject.macros).to eq subject.instance_variable_get(:@default)[:macros]
      end

    end 

    context 'with custom rules macros present' do

      context 'for same macro name' do

        let(:same_macro_name) { 'same-name' }

        subject do
          build(:risk, :with_default_macro, :with_custom_macro,
                default_macro_name: same_macro_name,
                custom_macro_name:  same_macro_name)
        end

        it 'merges default macro with custom macro attribues' do
          macros = subject.macros
          expect(macros.size).to eq 1

          # expect custom macro to override deault one with the same id
          expected_macro = subject.instance_variable_get(:@custom)[:macros][same_macro_name]

          expect(macros).to include(same_macro_name => expected_macro)
        end

      end

      context 'for different macro names' do

        let(:default_name) { 'macro-name' }
        let(:custom_name)  { 'other-macro-name' }

        subject do
          build(:risk, :with_default_macro, :with_custom_macro,
              default_macro_name: default_name,
              custom_macro_name:  custom_name)
        end

        it 'merges deafult and custom macros together' do
          macros = subject.macros
          expect(macros.keys.size).to eq 2
          expect(macros.keys).to include(default_name)
          expect(macros.keys).to include(custom_name)
        end

      end
      
    end 

  end

end
