require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/lock_races"

# A bid against the close of one due listing, each on its own connection, so the test commits for real
# and removes what it wrote, the settlement's rows of its two players included.
class Game::Market::PlaceBidRaceTest < ActiveSupport::TestCase
  include Holdings
  include LockRaces
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  self.use_transactional_tests = false

  setup do
    @seller = Accounts::Player.create!(steam_id: "76561197960299001", persona_name: "Race seller")
    @leader = Accounts::Player.create!(steam_id: "76561197960299002", persona_name: "Race leader")
    @bidder = Accounts::Player.create!(steam_id: "76561197960299003", persona_name: "Race bidder")
    @card = catalog_card_seasons(:common_card_one)
    @settings = open_market!(commission_basis_points: 1_000)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @leader, @bidder ].each { fund!(it, 100_000) }
    bid(@leader, 30_000)
    @listing.update_columns(ends_at: 1.second.ago)
  end

  teardown do
    players = [ @seller, @leader, @bidder ].map(&:id)
    Game::Market::Bid.where(listing_id: @listing.id).delete_all
    Game::Market::LedgerEntry.where(player_id: players).delete_all
    Game::Market::Wallet.where(player_id: players).delete_all
    Game::Market::Listing.where(id: @listing.id).delete_all
    Game::Market::EditionPrice.where(card_season_id: @card.id).delete_all
    purge_player_rows(players)
    purge_events(players)
    Game::Market::Settings.where(id: @settings.id).delete_all
    Accounts::Player.where(id: players).delete_all
  end

  def place = -> { bid(Accounts::Player.find(@bidder.id), 40_000) }

  def close = -> { Game::Market::CloseAuction.new.call(player: Accounts::Player.find(@seller.id), listing_id: @listing.id) }

  def settled_once
    assert_equal [ "sold" ], [ @listing.reload.status ]
    assert_equal [ 0, 0 ], Game::Holding.find_by(player_id: @seller.id, card_season_id: @card.id).attributes.values_at("quantity", "reserved")
    assert_equal 1, Game::Holding.where(card_season_id: @card.id, player_id: [ @leader.id, @bidder.id ]).sum(:quantity)
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a bid and a close at once settle once or refuse the bid" do
    bidding, closing = together(place, close)

    assert_includes [ [ :auction_ended ], [] ], [ bidding.failure ].compact
    assert_includes [ [ :listing_not_closable ], [] ], [ closing.failure ].compact
    assert_predicate closing, :success?
    settled_once
  end

  test "a close that holds the lock first refuses the late bid" do
    closing, bidding = first_holding_the_lock(-> { close.call.value! }, place)

    assert_equal :auction_ended, bidding.failure
    assert_equal @leader.id, @listing.reload.leader_id
    assert closing
    settled_once
  end

  test "a bid that holds the lock first on a due listing is refused and the close settles" do
    bidding, closing = first_holding_the_lock(place, close)

    assert_equal :auction_ended, bidding.failure
    assert_predicate closing, :success?
    settled_once
  end
end
