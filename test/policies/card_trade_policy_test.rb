require "test_helper"

class CardTradePolicyTest < ActiveSupport::TestCase
  test "a visitor may not ask for a card" do
    assert_not CardTradePolicy.new(nil, :card_trade).create?
  end

  test "a player may ask for a card" do
    assert CardTradePolicy.new(accounts_players(:player), :card_trade).create?
  end
end
