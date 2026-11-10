require "test_helper"

module BackOffice
  class MarketPolicyTest < ActiveSupport::TestCase
    def policy_for(role)
      MarketPolicy.new(role == :visitor ? nil : accounts_players(role), :market)
    end

    [ :visitor, :player ].each do |role|
      test "a #{role} may not read the market page" do
        assert_not policy_for(role).show?
      end
    end

    [ :moderator, :administrator ].each do |role|
      test "a #{role} reads the market page" do
        assert policy_for(role).show?
      end
    end
  end
end
