require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/lock_races"

# A bid against a cancel of one listing, each on its own connection, so the test commits for real and removes what it wrote.
class Game::Market::CancelListingRaceTest < ActiveSupport::TestCase
  include Holdings
  include LockRaces
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  self.use_transactional_tests = false

  setup do
    @seller = Accounts::Player.create!(steam_id: "76561197960299011", persona_name: "Race seller")
    @bidder = Accounts::Player.create!(steam_id: "76561197960299012", persona_name: "Race bidder")
    @card = catalog_card_seasons(:common_card_one)
    @settings = open_market!
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    fund!(@bidder, 100_000)
  end

  teardown do
    players = [ @seller.id, @bidder.id ]
    Game::Market::Bid.where(listing_id: @listing.id).delete_all
    Game::Market::LedgerEntry.where(player_id: players).delete_all
    Game::Market::Wallet.where(player_id: players).delete_all
    Game::Market::Listing.where(id: @listing.id).delete_all
    purge_player_rows(players)
    purge_events(players)
    Game::Market::Settings.where(id: @settings.id).delete_all
    Accounts::Player.where(id: players).delete_all
  end

  def place = -> { bid(Accounts::Player.find(@bidder.id), 30_000) }

  def cancel = -> { Game::Market::CancelListing.new.call(player: Accounts::Player.find(@seller.id), listing_id: @listing.id) }

  def reserved = Game::Holding.find_by!(player_id: @seller.id, card_season_id: @card.id).reserved

  def consistent
    @listing.reload
    if @listing.status == "cancelled"
      assert_nil @listing.leader_id
      assert_equal 0, reserved
      assert_equal [ 100_000, 0 ], figures(@bidder)
    else
      assert_equal [ "open", @bidder.id ], [ @listing.status, @listing.leader_id ]
      assert_equal 1, reserved
    end
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a bid and a cancel at once end with a leader or with a cancelled listing, never both" do
    bidding, cancelling = together(place, cancel)

    assert_includes [ [], [ :auction_ended ] ], [ bidding.failure ].compact
    assert_includes [ [], [ :bid_standing ] ], [ cancelling.failure ].compact
    assert_equal 1, [ bidding, cancelling ].count(&:success?)
    consistent
  end

  test "a cancel that holds the lock first refuses the late bid" do
    cancelling, bidding = first_holding_the_lock(-> { cancel.call.value! }, place)

    assert cancelling
    assert_equal :auction_ended, bidding.failure
    consistent
  end

  test "a bid that holds the lock first refuses the cancel" do
    bidding, cancelling = first_holding_the_lock(-> { place.call.value! }, cancel)

    assert bidding
    assert_equal :bid_standing, cancelling.failure
    consistent
  end
end
