require "test_helper"

class TradeSuggestionPolicyTest < ActiveSupport::TestCase
  test "a visitor may not send a suggestion" do
    assert_not TradeSuggestionPolicy.new(nil, :trade_suggestion).create?
  end

  [ :player, :moderator, :administrator ].each do |role|
    test "a #{role} may send a suggestion" do
      assert TradeSuggestionPolicy.new(accounts_players(role), :trade_suggestion).create?
    end
  end
end
