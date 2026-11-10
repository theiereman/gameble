require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::CancelListingTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @bidder = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    @settings = open_market!(first_opened_at: 1.day.ago)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    fund!(@bidder, 100_000)
  end

  def cancel(listing = @listing, player: @seller) = Game::Market::CancelListing.new.call(player:, listing_id: listing.id)

  def refused(player: @seller)
    failure = nil
    nothing_changes { failure = cancel(player:).failure }
    failure
  end

  def reserved = Game::Holding.find_by!(player_id: @seller.id, card_season_id: @card.id).reserved

  test "cancelling frees the copy, writes no ledger entry and publishes one event" do
    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      result = cancel

      assert result.success?
      assert_equal @listing, result.value!
    end

    assert_equal "cancelled", @listing.reload.status
    assert_equal 0, reserved
    published = events(Game::Market::ListingCancelled)
    assert_equal 1, published.size
    assert_equal({ listing_id: @listing.id, seller_id: @seller.id }, published.first.data)
  end

  test "the stamp is not refunded" do
    fund!(@seller, 1_000)
    Game::Market::Ledger.post(Game::Market::Ledger::Entry.new(player_id: @seller.id, kind: :stamp, available_delta: -500, listing_id: @listing.id, settings_id: @settings.id))
    before = figures(@seller)

    assert cancel.success?

    assert_equal before, figures(@seller)
  end

  test "a closed market still accepts a cancel" do
    close_market!(first_opened_at: 1.day.ago)

    assert cancel.success?
    assert_equal "cancelled", @listing.reload.status
  end

  test "a leader refuses it and nothing changes" do
    assert bid(@bidder, 30_000).success?

    assert_equal :bid_standing, refused
    assert_equal 1, reserved
  end

  test "a removed leader still counts as a leader" do
    lead!(@listing, @bidder, 30_000)
    @bidder.update_columns(banned_at: Time.current)

    assert_equal :bid_standing, refused
  end

  test "a listing at its end refuses it" do
    @listing.update_columns(ends_at: 1.second.ago)

    assert_equal :auction_ended, refused
  end

  %w[sold unsold cancelled withdrawn].each do |status|
    test "a #{status} listing refuses it" do
      @listing.update_columns(status:)

      assert_equal :auction_ended, refused
    end
  end

  test "another seller and an unknown listing are not found" do
    other = accounts_players(:administrator)

    assert_equal :listing_not_found, refused(player: other)
    assert_equal :listing_not_found, Game::Market::CancelListing.new.call(player: @seller, listing_id: 0).failure
  end

  test "a banned player cannot cancel" do
    @seller.update_columns(banned_at: Time.current)

    assert_equal :player_required, refused
  end

  test "a second cancel finds the listing cancelled" do
    assert cancel.success?

    assert_equal :auction_ended, cancel.failure
    assert_equal 0, reserved
  end

  test "a bid placed first makes the cancel refuse, and the ledger reconciles" do
    assert bid(@bidder, 30_000).success?

    assert_equal :bid_standing, cancel.failure
    assert_equal "open", @listing.reload.status
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a bid after the cancel is refused as ended" do
    assert cancel.success?

    assert_equal :auction_ended, bid(@bidder, 30_000).failure
    assert_equal [ 100_000, 0 ], figures(@bidder)
  end
end
