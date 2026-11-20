require "test_helper"
require_relative "../../../support/market"

class Game::Market::OrderEventsTest < ActiveSupport::TestCase
  include MarketSettings

  setup do
    @buyer = accounts_players(:player)
    @seller = accounts_players(:moderator)
    @season = catalog_card_seasons(:common_card_one)
    @order = Game::Market::Order.create!(player: @buyer, card_id: @season.card_id, settings: open_market!, price: 120, expires_at: 7.days.from_now,
      status: "served", seller_id: @seller.id, served_card_season_id: @season.id, served_at: Time.current, average_after_sale: 110)
  end

  test "an order's own events carry the order, its buyer, its card and its amount" do
    [ Game::Market::OrderPlaced, Game::Market::OrderCancelled, Game::Market::OrderExpired, Game::Market::OrderWithdrawn ].each do |event|
      assert_equal({ order_id: @order.id, player_id: @buyer.id, card_id: @season.card_id, amount: 120 }, event.about(@order).data)
    end
  end

  test "a served order carries both players, the copy and the price" do
    assert_equal({ order_id: @order.id, buyer_id: @buyer.id, seller_id: @seller.id, card_season_id: @season.id, price: 120 },
      Game::Market::OrderServed.about(@order).data)
  end

  test "applied wanted choices keep only the declared keys of each sale and entrusted line, and refuse a missing one" do
    sale = { order_id: @order.id, buyer_id: @buyer.id, card_season_id: @season.id, price: 120, extra: 1 }
    data = Game::Market::WantedChoicesApplied.with(seller_id: @seller.id, sales: [ sale ], listing_ids: [ 4 ],
      entrusted: [ { card_season_id: @season.id, quantity: 2 } ]).data

    assert_equal({ seller_id: @seller.id, sales: [ sale.except(:extra) ], listing_ids: [ 4 ], entrusted: [ { card_season_id: @season.id, quantity: 2 } ] }, data)
    assert_raises(KeyError) { Game::Market::WantedChoicesApplied.with(seller_id: 1, sales: [ sale.except(:price) ], listing_ids: [], entrusted: []) }
  end

  test "an Archive purchase and a bought slot carry their keys" do
    assert_equal({ player_id: 1, card_season_id: 2, price: 3 }, Game::Market::ArchivePurchased.with(player_id: 1, card_season_id: 2, price: 3).data)
    assert_equal({ player_id: 1, kind: "goal", goal_id: nil }, Game::SlotBought.with(player_id: 1, kind: "goal").data)
  end
end
