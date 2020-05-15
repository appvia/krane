RSpec.describe Krane::Config::Whitelist do

  let(:rule_id)       { :some_rule_id }
  let(:cluster_name)  { :minikube }
  let(:whitelist_key) { :whitelisted_subjects }

  before do
    @whitelist_for_risk_item = subject.for_risk_item(rule_id, cluster_name)
  end

  describe '#for_risk_item' do

    context 'with global whitelist key-value pairs' do

      let(:whitelisted_items) do 
        [
          'global_item_1',
          'global_item_2',
        ]
      end

      subject do
        build(
          :whitelist, :with_global_config, 
          global_whitelist_key:  whitelist_key,
          global_whitelist_vals: whitelisted_items
        )
      end

      it 'contains global key-pairs' do
        expect(@whitelist_for_risk_item).to include(
          { whitelist_key => whitelisted_items.uniq.sort}
        )
      end

    end

    context 'with common (all clusters) whitelist key-value pairs for desired risk rule id' do

      let(:whitelisted_items) do 
        [
          'common_item_1', 
          'common_item_2',
        ]
      end

      subject do
        build( 
          :whitelist, :with_common_config, 
          common_rule_id:        rule_id,
          common_whitelist_key:  whitelist_key,
          common_whitelist_vals: whitelisted_items
        )
      end

      it 'contains common risk item whitelist key-value pairs' do
        expect(@whitelist_for_risk_item).to include(
          { whitelist_key => whitelisted_items.uniq.sort}
        )
      end

    end

    context 'with cluster specific whitelist key-value pairs for desired cluster name and risk rule id' do

      let(:whitelisted_items) do 
        [
          'cluster_item_1', 
          'cluster_item_2'
        ]
      end

      subject do
        build(
          :whitelist, :with_cluster_config, 
          cluster_name:           cluster_name,
          cluster_rule_id:        rule_id,
          cluster_whitelist_key:  whitelist_key,
          cluster_whitelist_vals: whitelisted_items
        )
      end

      it 'contains cluster specific risk item whitelist key-value pairs' do
        expect(@whitelist_for_risk_item).to include(
          { whitelist_key => whitelisted_items.uniq.sort}
        )
      end

    end


    context 'with out-of-scope risk rule id or cluster name' do

      let(:whitelisted_items) do
        [
          'item1', 
          'item2',
        ]
      end

      context 'for common whitelist key-value pairs defined for out-of-scope risk rule id ' do

        subject do
          build(
            :whitelist, :with_common_config,
            # common overrides
            common_rule_id:        'out-of-scope-rule',
            common_whitelist_key:  whitelist_key,
            common_whitelist_vals: whitelisted_items,
          )
        end

        it 'skips common whitelist and returns empty hash' do
          expect(@whitelist_for_risk_item).to be {}
        end
      end


      context 'for cluster specific whitelist key-value pairs defined for out-of-scope cluster name' do

        subject do
          build(
            :whitelist,  :with_cluster_config, 
            # cluster overrides
            cluster_name:           'out-of-scope-cluster-name',
            cluster_rule_id:        rule_id,
            cluster_whitelist_key:  whitelist_key,
            cluster_whitelist_vals: whitelisted_items
          )
        end

        it 'skips cluster whitelist and returns empty hash' do
          expect(@whitelist_for_risk_item).to be {}
        end

      end

      context 'for cluster specific whitelist key-value pairs defined for out-of-scope risk rule id' do

        subject do
          build(
            :whitelist, :with_cluster_config, 
            # cluster overrides
            cluster_name:           cluster_name,
            cluster_rule_id:        'out-of-scope-rule-id',
            cluster_whitelist_key:  whitelist_key,
            cluster_whitelist_vals: whitelisted_items
          )
        end

        it 'skips cluster whitelist and returns empty hash' do
          expect(@whitelist_for_risk_item).to be {}
        end

      end

    end

    context 'with global, common and cluster specific whitelist items defined for desired cluster name and risk rule id' do

      let(:global_whitelisted_items) do 
        [
          'item1',
          'item2',
        ]
      end

      let(:common_whitelisted_items) do 
        [
          'item3', 
          'item4',
          'item5',
        ]
      end

      let(:cluster_whitelisted_items) do 
        [
          'item1', # also specified in global whitelist
          'item3', # also specified in common whitelist
          'item6',
        ]
      end

      let(:expected_whitelist_items) do
        [ 
          global_whitelisted_items, 
          common_whitelisted_items, 
          cluster_whitelisted_items
        ].flatten.uniq.sort
      end

      subject do
        build(
          :whitelist, :with_global_config, :with_common_config, :with_cluster_config, 
          # global overrides
          global_whitelist_key:  whitelist_key,
          global_whitelist_vals: global_whitelisted_items,
          # common overrides
          common_rule_id:        rule_id,
          common_whitelist_key:  whitelist_key,
          common_whitelist_vals: common_whitelisted_items,
          # cluster overrides
          cluster_name:           cluster_name,
          cluster_rule_id:        rule_id,
          cluster_whitelist_key:  whitelist_key,
          cluster_whitelist_vals: cluster_whitelisted_items,
        )
      end


      it 'contains cluster specific risk item whitelist key-value pairs' do
        expect(@whitelist_for_risk_item).to include(
          { whitelist_key => expected_whitelist_items}
        )
      end

    end

  end

end
