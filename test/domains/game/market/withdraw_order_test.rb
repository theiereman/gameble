require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_orders"

class Game::Market::WithdrawOrderTest < ActiveSupport::TestCase
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketOrders
  include MarketSettings

  setup do
    @owner = accounts_players(:player)
    @card = catalog_card_seasons(:rare_card_one)
    @settings = open_market!
    fund!(@owner, 1_000)
    @order = order!(@owner, @card, 900)
    listing = listing!(seller: accounts_players(:moderator), card_season: @card, starting_price: 1_200)
    Game::Market::Notice.record(player_id: @owner.id, listing_id: listing.id, order_id: @order.id, kind: "listed_above_order", amount: 1_200)
    Game::Market::Wanted.transaction do
      Game::TradeLocks.players(@owner.id)
      Game::Market::RefreshWanted.call(@owner)
    end
  end

  def withdraw(order_id: @order.id) = Game::Market::WithdrawOrder.new.call(player: @owner, order_id:)

  def ban = @owner.update_columns(banned_at: Time.current)

  def delete = @owner.update_columns(deleted_at: Time.current, steam_id: nil)

  def nothing_moves(&)
    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Rails.configuration.event_store.read.count } ], &)
  end

  test "a banned owner's order is withdrawn, its price released once, its notice and wanted rows gone, one OrderWithdrawn published" do
    assert_equal [ "order" ], Game::Market::Wanted.where(player_id: @owner.id).pluck(:reason)
    ban

    assert withdraw.success?

    assert_equal "withdrawn", @order.reload.status
    assert_equal [ 1_000, 0 ], figures(@owner)
    release = Game::Market::LedgerEntry.where(order_id: @order.id, kind: "release").sole
    assert_equal [ 900, -900, @settings.id ], release.attributes.values_at("available_delta", "committed_delta", "settings_id")
    assert_empty Game::Market::Notice.where(order_id: @order.id)
    assert_empty Game::Market::Wanted.where(player_id: @owner.id)
    stream = Rails.configuration.event_store.read.stream(Game::Operation.stream_name(@owner.id)).of_type(Game::Market::OrderWithdrawn).to_a
    assert_equal [ @order.id ], stream.map { it.data[:order_id] }
  end

  test "a deleted owner's order is withdrawn" do
    delete

    assert withdraw.success?

    assert_equal "withdrawn", @order.reload.status
    assert_equal [ 1_000, 0 ], figures(@owner)
    assert_empty Game::Market::Wanted.where(player_id: @owner.id)
  end

  test "a due order of a removed owner is withdrawn" do
    @order.update_columns(expires_at: 1.minute.ago)
    delete

    assert withdraw.success?
    assert_equal "withdrawn", @order.reload.status
  end

  test "a present owner's order is not withdrawable" do
    nothing_moves { assert_equal Game::Market::WithdrawOrder::NOT_WITHDRAWABLE, withdraw }
    assert_equal "open", @order.reload.status
  end

  test "an ended order is not withdrawable" do
    ban
    %w[cancelled expired withdrawn].each do |status|
      @order.update_columns(status:)

      nothing_moves { assert_equal Game::Market::WithdrawOrder::NOT_WITHDRAWABLE, withdraw }
    end
  end

  test "another player's order is not withdrawable" do
    ban

    nothing_moves { assert_equal Game::Market::WithdrawOrder::NOT_WITHDRAWABLE, Game::Market::WithdrawOrder.new.call(player: accounts_players(:moderator), order_id: @order.id) }
  end

  test "a second call releases nothing more" do
    ban
    assert withdraw.success?

    nothing_moves { assert_equal Game::Market::WithdrawOrder::NOT_WITHDRAWABLE, withdraw }
  end
end
