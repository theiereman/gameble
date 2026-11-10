require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::WithdrawListingTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @leader = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(increment_basis_points: 500)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    fund!(@leader, 100_000)
  end

  def ban(player = @seller) = player.update_columns(banned_at: Time.current)

  def delete(player = @seller)
    player.update_columns(deleted_at: Time.current)
    Game::Holding.where(player_id: player.id).delete_all
  end

  def withdraw(listing = @listing) = Game::Market::WithdrawListing.new.call(player: @seller, listing_id: listing.id)

  def reserved = Game::Holding.find_by(player_id: @seller.id, card_season_id: @card.id)&.reserved

  test "a banned seller's listing with a bid is withdrawn, the leader's maximum released and the card released" do
    bid(@leader, 30_000)
    ban

    assert withdraw.success?

    assert_equal [ "withdrawn", nil, nil ], @listing.reload.attributes.values_at("status", "leader_id", "leader_maximum")
    assert_equal [ 100_000, 0 ], figures(@leader)
    assert_equal 0, reserved
    assert_equal 1, entries_of.where(player_id: @leader.id, kind: "release").count
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a listing with no bid is withdrawn without a ledger entry" do
    ban

    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      assert withdraw.success?
    end

    assert_equal [ "withdrawn", 0 ], [ @listing.reload.status, reserved ]
  end

  test "a deleted seller's listing is withdrawn although the holding is gone" do
    bid(@leader, 30_000)
    delete

    assert withdraw.success?

    assert_equal "withdrawn", @listing.reload.status
    assert_nil reserved
    assert_equal [ 100_000, 0 ], figures(@leader)
  end

  test "the stamp is never refunded" do
    ban

    assert_no_difference -> { Game::Market::LedgerEntry.where(kind: %w[stamp]).count } do
      assert withdraw.success?
    end

    assert_empty entries_of.where(player_id: @seller.id)
  end

  test "a removed seller and a removed leader are withdrawn together with one release" do
    bid(@leader, 30_000)
    ban
    ban(@leader)

    assert withdraw.success?

    assert_equal [ 100_000, 0 ], figures(@leader)
    assert_equal 1, entries_of.where(kind: "release").count
  end

  test "it publishes one withdrawal with the released amount" do
    bid(@leader, 30_000)
    ban

    assert_difference -> { events(Game::Market::ListingWithdrawn).size }, 1 do
      withdraw
    end

    assert_equal({ listing_id: @listing.id, seller_id: @seller.id, leader_id: @leader.id, released: 30_000 }, events(Game::Market::ListingWithdrawn).last.data)
  end

  test "a listing past its end is withdrawn too" do
    ban
    @listing.update_columns(ends_at: 1.minute.ago)

    assert withdraw.success?
    assert_equal "withdrawn", @listing.reload.status
  end

  test "a present seller's, a closed and an already withdrawn listing are skipped" do
    nothing_changes { assert_equal Game::Market::WithdrawListing::NOT_WITHDRAWABLE, withdraw }

    ban
    assert withdraw.success?
    nothing_changes { assert_equal Game::Market::WithdrawListing::NOT_WITHDRAWABLE, withdraw }
  end

  test "the close of a removed seller's due auction withdraws it the same way, even for a deleted seller" do
    bid(@leader, 30_000)
    delete
    @listing.update_columns(ends_at: 1.minute.ago)

    assert Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id).success?

    assert_equal "withdrawn", @listing.reload.status
    assert_equal [ 100_000, 0 ], figures(@leader)
  end

  test "the withdrawn listing reads as withdrawn on MES VENTES and on the Annonce" do
    ban
    assert withdraw.success?

    row = Game::Market::SellerListings.call(player: @seller, locale: :en).ended.sole
    outcome = Game::Market::ListingOutcome.call(token: @listing.token, viewer: nil, locale: :en)

    assert_equal [ "withdrawn", :withdrawn ], [ row.status, outcome.kind ]
  end
end
