require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::CancelOrderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include MarketAuctions
  include MarketBidding
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @settings = open_market!
    fund!(@player, 1_000)
    @order = Game::Market::PlaceOrder.new.call(player: @player, card_id: catalog_cards(:common_card).id, price: 300, settings_token: @settings.token).value!
  end

  def cancel(player: @player, order_id: @order.id) = Game::Market::CancelOrder.new.call(player:, order_id:)

  test "a cancel releases the held price, free, and publishes one OrderCancelled" do
    assert cancel.success?

    assert_equal "cancelled", @order.reload.status
    assert_equal [ 1_000, 0 ], figures(@player)
    release = Game::Market::LedgerEntry.find_by!(order_id: @order.id, kind: "release")
    assert_equal [ 300, -300, @settings.id ], release.attributes.values_at("available_delta", "committed_delta", "settings_id")
    assert_equal [ @order.id ], events(Game::Market::OrderCancelled).map { it.data[:order_id] }
  end

  test "a cancel works while the market is closed" do
    close_market!(first_opened_at: 1.day.ago)

    assert cancel.success?
    assert_equal [ 1_000, 0 ], figures(@player)
  end

  test "the balance notice leaves once the cancel commits" do
    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @player.id, balance: true } ] ]) { assert cancel.success? }
  end

  test "a second cancel refuses and moves nothing" do
    cancel

    assert_no_difference(-> { Game::Market::LedgerEntry.count }) { assert_equal :order_not_open, cancel.failure }
  end

  test "another player's order or an unknown one is not found" do
    assert_equal :order_not_found, cancel(player: accounts_players(:moderator)).failure
    assert_equal :order_not_found, cancel(order_id: 0).failure
    assert_equal "open", @order.reload.status
  end
end
