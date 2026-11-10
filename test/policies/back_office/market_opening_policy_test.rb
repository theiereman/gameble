require "test_helper"

module BackOffice
  class MarketOpeningPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      MarketOpeningPolicy.new(role == :visitor ? nil : accounts_players(role), :market_opening)
    end

    [ :visitor, :player, :moderator ].each do |role|
      test "a #{role} may not open the market" do
        assert_not policy_for(role).create?
      end
    end

    test "an administrator opens the market" do
      assert policy_for(:administrator).create?
    end
  end
end
