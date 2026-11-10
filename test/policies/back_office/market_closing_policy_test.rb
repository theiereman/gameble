require "test_helper"

module BackOffice
  class MarketClosingPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      MarketClosingPolicy.new(role == :visitor ? nil : accounts_players(role), :market_closing)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may not close the market" do
        assert_not policy_for(role).create?
      end
    end

    test "an administrator closes the market" do
      assert policy_for(:administrator).create?
    end
  end
end
