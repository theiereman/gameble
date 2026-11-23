require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_orders"

class Game::Market::BestVisibleOrderTest < ActiveSupport::TestCase
  include MarketAuctions
  include MarketOrders
  include MarketSettings

  setup do
    @viewer = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    open_market!
    @now = Time.current
    @standing = 2.hours.ago
  end

  def funded_buyer(player = buyer!) = player.tap { fund!(it, 100_000) }

  def best = Game::Market::BestVisibleOrder.call(@common.card_id, viewer: @viewer, now: @now)

  def tie!(one, other)
    low, high = [ one, other ].sort_by(&:id)
    Game::Market::TiedAccount.create!(low_account: low, high_account: high, signal: "one_way_trades", facts: {}, refreshed_at: @now)
  end

  test "the best price of the others' open orders standing over an hour" do
    order!(funded_buyer, @common, 80, created_at: @standing)
    order!(funded_buyer, @common, 60, created_at: @standing)
    order!(funded_buyer, catalog_card_seasons(:rare_card_one), 900, created_at: @standing)

    assert_equal 80, best
  end

  test "an order under an hour, the viewer's own, a removed owner's, a tied account's, a due and an ended one are skipped" do
    order!(funded_buyer, @common, 500, created_at: @now - 59.minutes)
    order!(funded_buyer(@viewer), @common, 500, created_at: @standing)
    order!(funded_buyer(accounts_players(:banned)), @common, 500, created_at: @standing)
    order!(funded_buyer.tap { it.update_columns(deleted_at: 1.hour.ago) }, @common, 500, created_at: @standing)
    order!(funded_buyer.tap { tie!(@viewer, it) }, @common, 500, created_at: @standing)
    order!(funded_buyer, @common, 500, created_at: @standing, expires_at: @now)
    order!(funded_buyer, @common, 500, created_at: @standing).update!(status: "cancelled")

    assert_nil best
  end

  test "a tied account is skipped from either side of the pair" do
    lower, higher = [ buyer!, buyer! ].sort_by(&:id)
    order!(funded_buyer(lower), @common, 500, created_at: @standing)

    assert_equal 500, Game::Market::BestVisibleOrder.call(@common.card_id, viewer: higher, now: @now)
    tie!(lower, higher)
    assert_nil Game::Market::BestVisibleOrder.call(@common.card_id, viewer: higher, now: @now)
    order!(funded_buyer(higher), @common, 400, created_at: @standing)
    assert_nil Game::Market::BestVisibleOrder.call(@common.card_id, viewer: lower, now: @now)
  end
end
