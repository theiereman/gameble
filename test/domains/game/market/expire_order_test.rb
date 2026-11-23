require "test_helper"
require_relative "../../../support/singleton_stub"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/market_orders"

class Game::Market::ExpireOrderTest < ActiveSupport::TestCase
  include SingletonStub
  include MarketAuctions
  include MarketBidding
  include MarketOrders
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @settings = open_market!
    fund!(@player, 1_000)
    @order = order!(@player, catalog_card_seasons(:common_card_one), 300, expires_at: 1.minute.ago)
  end

  def expire(player: @player, order_id: @order.id) = Game::Market::ExpireOrder.new.call(player:, order_id:)

  def nothing_moves(&)
    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Rails.configuration.event_store.read.count } ], &)
  end

  test "a due order expires, its price released once, and publishes one OrderExpired on the owner's stream" do
    assert expire.success?

    assert_equal "expired", @order.reload.status
    assert_equal [ 1_000, 0 ], figures(@player)
    release = Game::Market::LedgerEntry.find_by!(order_id: @order.id, kind: "release")
    assert_equal [ 300, -300, @settings.id ], release.attributes.values_at("available_delta", "committed_delta", "settings_id")
    assert_equal [ @order.id ], events(Game::Market::OrderExpired).map { it.data[:order_id] }
    stream = Rails.configuration.event_store.read.stream(Game::Operation.stream_name(@player.id)).of_type(Game::Market::OrderExpired).to_a
    assert_equal 1, stream.size
  end

  test "an order not yet due is left open" do
    @order.update_columns(expires_at: 1.minute.from_now)

    nothing_moves { assert_equal Game::Market::ExpireOrder::NOT_DUE, expire }
    assert_equal "open", @order.reload.status
  end

  test "an order already ended is not due" do
    %w[cancelled expired withdrawn].each do |status|
      @order.update_columns(status:)

      nothing_moves { assert_equal Game::Market::ExpireOrder::NOT_DUE, expire }
      assert_equal status, @order.reload.status
    end
  end

  test "a served order is not due" do
    @order.update_columns(status: "served", seller_id: accounts_players(:moderator).id, served_card_season_id: catalog_card_seasons(:common_card_one).id,
      served_at: Time.current, average_after_sale: 300)

    nothing_moves { assert_equal Game::Market::ExpireOrder::NOT_DUE, expire }
  end

  test "a due order expires while the market is closed" do
    close_market!(first_opened_at: 1.day.ago)

    assert expire.success?
    assert_equal [ 1_000, 0 ], figures(@player)
  end

  test "a banned owner's order still expires and the money is released" do
    @player.update_columns(banned_at: Time.current)

    assert expire(player: @player.reload).success?
    assert_equal [ 1_000, 0 ], figures(@player)
  end

  test "another player's order is not found" do
    assert_equal :order_not_found, expire(player: accounts_players(:moderator)).failure
    assert_equal "open", @order.reload.status
  end

  test "a deadlock is the market busy and moves nothing" do
    stub_singleton(Game::Market::Ledger, :post, ->(*) { raise ActiveRecord::Deadlocked }) do
      nothing_moves { assert_equal :market_busy, expire.failure }
    end
    assert_equal "open", @order.reload.status
  end
end
