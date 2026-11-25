require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::RepriceOrderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include MarketAuctions
  include MarketBidding
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @settings = open_market!(order_duration_days: 7)
    fund!(@player, 70)
    @order = Game::Market::PlaceOrder.new.call(player: @player, card_id: catalog_cards(:common_card).id, price: 20, settings_token: @settings.token).value!
  end

  def reprice(price, player: @player, order_id: @order.id, settings_token: @settings.token)
    Game::Market::RepriceOrder.new.call(player:, order_id:, price:, settings_token:)
  end

  def nothing_written(&)
    assert_no_difference([ -> { Game::Market::Order.count }, -> { Game::Market::LedgerEntry.count }, -> { Rails.configuration.event_store.read.count } ], &)
  end

  def refused(code, price, **)
    result = nil
    nothing_written { result = reprice(price, **) }
    assert_equal code, result.failure
    assert_equal [ "open", 20 ], @order.reload.attributes.values_at("status", "price")
  end

  def entry(order, kind) = Game::Market::LedgerEntry.find_by!(order_id: order.id, kind:).attributes.values_at("available_delta", "committed_delta")

  test "a raise replaces the order: the old one cancelled and released, a new one held at the new price, one OrderRepriced" do
    travel 1.day
    order = reprice(30).value!

    assert_equal "cancelled", @order.reload.status
    assert_equal [ 20, -20 ], entry(@order, :release)
    assert_equal [ "open", 30, @order.card_id, @settings.id ], order.attributes.values_at("status", "price", "card_id", "settings_id")
    assert_not_equal @order.token, order.token
    assert_in_delta 7.days.from_now, order.expires_at, 1.second
    assert_equal [ -30, 30 ], entry(order, :hold)
    assert_equal [ 40, 30 ], figures(@player)
    assert_equal [ { replaced_order_id: @order.id, order_id: order.id, player_id: @player.id, card_id: @order.card_id, previous_amount: 20, amount: 30 } ],
      events(Game::Market::OrderRepriced).map(&:data)
  end

  test "a lower price holds only the new price" do
    order = reprice("15").value!

    assert_equal [ 55, 15 ], figures(@player)
    assert_equal [ "open", 15 ], order.attributes.values_at("status", "price")
  end

  test "coverage counts the old order's release" do
    assert reprice(70).success?

    assert_equal [ 0, 70 ], figures(@player)
  end

  test "the same price succeeds and writes nothing" do
    nothing_written { assert_equal @order, reprice(20).value! }
  end

  test "a price the available balance and the release do not cover refuses" do
    refused(:not_covered, 71)
  end

  test "a price under every minimum refuses" do
    refused(:order_below_minimum, 5)
  end

  test "an order no longer open refuses" do
    @order.update_columns(status: "expired")

    result = nil
    nothing_written { result = reprice(30) }
    assert_equal :order_not_open, result.failure
  end

  test "another player's order is not found" do
    refused(:order_not_found, 30, player: accounts_players(:moderator).tap { fund!(it, 100) })
  end

  test "a closed market refuses" do
    close_market!(first_opened_at: 1.day.ago)

    refused(:market_closed, 30)
  end

  test "a stale settings version refuses" do
    refused(:amounts_changed, 30, settings_token: "stale")
  end

  test "an order on a card no longer published refuses" do
    card = Catalog::Card.create!(source_key: "src:902", release_date: Date.new(2000, 1, 1), image_url: "https://images.example.test/902.jpg",
      store_url: "https://store.example.test/902")
    @order.update_columns(card_id: card.id)

    result = nil
    nothing_written { result = reprice(30) }
    assert_equal :card_not_published, result.failure
  end

  test "a price that is no amount refuses" do
    assert_equal :invalid_price, reprice("abc").failure
  end

  test "the balance notice leaves once the reprice commits" do
    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @player.id, balance: true } ] ]) { assert reprice(30).success? }
  end
end
