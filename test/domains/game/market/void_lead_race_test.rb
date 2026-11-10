require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/lock_races"

# A bid against the void of a removed leader's lead, each on its own connection.
class Game::Market::VoidLeadRaceTest < ActiveSupport::TestCase
  include Holdings
  include LockRaces
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  self.use_transactional_tests = false

  setup do
    @seller = Accounts::Player.create!(steam_id: "76561197960299011", persona_name: "Void seller")
    @leader = Accounts::Player.create!(steam_id: "76561197960299012", persona_name: "Void leader")
    @bidder = Accounts::Player.create!(steam_id: "76561197960299013", persona_name: "Void bidder")
    @card = catalog_card_seasons(:common_card_one)
    @settings = open_market!
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @leader, @bidder ].each { fund!(it, 100_000) }
    bid(@leader, 30_000)
    @leader.update_columns(banned_at: Time.current)
  end

  teardown do
    players = [ @seller, @leader, @bidder ].map(&:id)
    Game::Market::Bid.where(listing_id: @listing.id).delete_all
    Game::Market::LedgerEntry.where(player_id: players).delete_all
    Game::Market::Wallet.where(player_id: players).delete_all
    Game::Market::Notice.where(listing_id: @listing.id).delete_all
    Game::Market::Listing.where(id: @listing.id).delete_all
    purge_player_rows(players)
    purge_events(players)
    Game::Market::Settings.where(id: @settings.id).delete_all
    Accounts::Player.where(id: players).delete_all
  end

  test "a bid and a void at once release the removed leader once and leave the money balanced" do
    void = -> { Game::Market::VoidLead.new.call(player: Accounts::Player.find(@seller.id), listing_id: @listing.id) }
    place = -> { bid(Accounts::Player.find(@bidder.id), 40_000) }

    together(place, void)

    assert_equal [ 100_000, 0 ], figures(@leader)
    assert_equal 1, entries_of.where(player_id: @leader.id, kind: "release").count
    assert Game::Market::ReconcileWallets.call.balanced?
  end
end
