require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_orders"

class Game::Market::OldestDueOrderTest < ActiveSupport::TestCase
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @buyer = accounts_players(:player)
    open_market!
    fund!(@buyer, 10_000)
  end

  test "nil when nothing is due" do
    order!(@buyer, catalog_card_seasons(:common_card_one), 300, expires_at: 1.hour.from_now)

    assert_nil Game::Market::OldestDueOrder.call
  end

  test "whole seconds since the oldest due open order's end" do
    now = Time.current
    order!(@buyer, catalog_card_seasons(:common_card_one), 300, expires_at: now - 90.seconds)
    order!(@buyer, catalog_card_seasons(:portal_one), 300, expires_at: now - 10.seconds)

    assert_equal 90, Game::Market::OldestDueOrder.call(now:)
  end

  test "an ended order does not count" do
    order!(@buyer, catalog_card_seasons(:common_card_one), 300, expires_at: 1.hour.ago).update_columns(status: "cancelled")

    assert_nil Game::Market::OldestDueOrder.call
  end
end
