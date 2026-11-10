require "test_helper"

module BackOffice
  class MarketSettingPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      MarketSettingPolicy.new(role == :visitor ? nil : accounts_players(role), :market_setting)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may not change the settings" do
        assert_not policy_for(role).create?
      end
    end

    test "an administrator changes the settings" do
      assert policy_for(:administrator).create?
    end
  end
end
