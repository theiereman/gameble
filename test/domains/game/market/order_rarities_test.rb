require "test_helper"
require_relative "../../../support/market"

class Game::Market::OrderRaritiesTest < ActiveSupport::TestCase
  include MarketSettings

  def fixture = JSON.parse(File.read(Rails.root.join("test/fixtures/files/order_reaching.json")))

  test "each case of the fixture reaches the rarities Order.reaching gives, among those its card is published at" do
    minimums = fixture["minimums"].transform_keys { :"minimum_price_#{it}" }
    settings = open_market!(**minimums)
    orders = fixture["cases"].to_h do |row|
      order = Game::Market::Order.create!(player: accounts_players(:player), card_id: catalog_cards(:common_card).id, settings:, price: row["price"],
        expires_at: 1.day.from_now, status: "cancelled")
      [ order.id, row ]
    end

    Game::Market::OrderRarities.call(orders.keys).each do |id, rarities|
      assert_equal orders[id]["reached"] & [ "common" ], rarities.map(&:to_s), orders[id].inspect
    end
  end

  test "an order on a card published only as a rare reaches nothing below the rare minimum" do
    settings = open_market!
    below = Game::Market::Order.create!(player: accounts_players(:player), card_id: catalog_cards(:rare_card).id, settings:,
      price: settings.minimum_price_rare - 1, expires_at: 1.day.from_now, status: "cancelled")
    at = Game::Market::Order.create!(player: accounts_players(:player), card_id: catalog_cards(:rare_card).id, settings:,
      price: settings.minimum_price_rare, expires_at: 1.day.from_now, status: "cancelled")

    assert_equal({ below.id => [], at.id => [ :rare ] }, Game::Market::OrderRarities.call([ below.id, at.id ]))
  end

  test "no order reaches nothing" do
    assert_equal({}, Game::Market::OrderRarities.call([]))
  end
end
