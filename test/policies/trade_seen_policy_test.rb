require "test_helper"

class TradeSeenPolicyTest < ActiveSupport::TestCase
  test "a visitor may not mark a trade seen" do
    assert_not TradeSeenPolicy.new(nil, :trade_seen).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may" do
      assert TradeSeenPolicy.new(accounts_players(role), :trade_seen).create?
    end
  end
end
