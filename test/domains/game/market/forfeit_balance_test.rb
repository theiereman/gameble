require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/holdings"

class Game::Market::ForfeitBalanceTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @player = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!
    fund!(@player, 5_000)
  end

  def delete(player = @player) = player.update_columns(deleted_at: Time.current)

  def forfeit(player = @player) = Game::Market::ForfeitBalance.new.call(player:)

  def figures = Game::Market::Wallet.find_by!(player_id: @player.id).attributes.values_at("available", "committed")

  def events = Rails.configuration.event_store.read.of_type(Game::Market::BalanceForfeited).to_a

  test "a deleted player's available PiCoins are forfeited in one entry and the wallet is at zero" do
    delete

    assert_difference -> { Game::Market::LedgerEntry.where(kind: "forfeit").count }, 1 do
      assert forfeit.success?
    end

    entry = Game::Market::LedgerEntry.where(kind: "forfeit").sole
    assert_equal [ @player.id, -5_000, 0, nil ], entry.attributes.values_at("player_id", "available_delta", "committed_delta", "listing_id")
    assert_equal [ 0, 0 ], figures
    assert_equal({ player_id: @player.id, amount: 5_000 }, events.last.data)
  end

  test "the reconciliation balances after a forfeit and counts it as destroyed" do
    before = Game::Market::ReconcileWallets.call.destroyed
    delete

    assert forfeit.success?

    assert_equal before + 5_000, Game::Market::ReconcileWallets.call.destroyed
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a banned or live player is refused and keeps the balance" do
    assert_equal Dry::Monads::Failure(:player_not_deleted), forfeit
    @player.update_columns(banned_at: Time.current)
    assert_equal Dry::Monads::Failure(:player_not_deleted), forfeit

    assert_equal [ 5_000, 0 ], figures
  end

  test "an open listing or a lead refuses the forfeit, and so do committed funds" do
    delete
    hold(@seller, @card.id, 1, reserved: 1)
    listing = listing!(seller: @seller, card_season: @card, ends_at: 1.day.from_now)
    lead!(listing, @player, 3_000)

    assert_equal Game::Market::ForfeitBalance::MARKET_PENDING, forfeit
    listing.update_columns(leader_id: nil, leader_maximum: nil)
    assert_equal Game::Market::ForfeitBalance::MARKET_PENDING, forfeit
    assert_equal [ 2_000, 3_000 ], figures
  end

  test "an open listing of the player refuses the forfeit" do
    delete
    hold(@player, @card.id, 1, reserved: 1)
    listing!(seller: @player, card_season: @card, ends_at: 1.day.from_now)

    assert_equal Game::Market::ForfeitBalance::MARKET_PENDING, forfeit
  end

  test "a zero balance, a missing wallet and a second run have nothing to forfeit" do
    delete
    assert forfeit.success?

    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      assert_equal Game::Market::ForfeitBalance::NOTHING_TO_FORFEIT, forfeit
      other = accounts_players(:administrator).tap { delete(it) }
      assert_equal Game::Market::ForfeitBalance::NOTHING_TO_FORFEIT, forfeit(other)
    end
  end
end
