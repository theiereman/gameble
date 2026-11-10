require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"
require_relative "../../../support/lock_races"

# The void of a deleted leader's lead against the forfeit of the same player's balance, each on its own connection.
class Game::Market::ForfeitBalanceRaceTest < ActiveSupport::TestCase
  include Holdings
  include LockRaces
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  self.use_transactional_tests = false

  setup do
    @seller = Accounts::Player.create!(steam_id: "76561197960299021", persona_name: "Forfeit seller")
    @leader = Accounts::Player.create!(steam_id: "76561197960299022", persona_name: "Forfeit leader")
    @card = catalog_card_seasons(:common_card_one)
    @settings = open_market!
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    fund!(@leader, 100_000)
    bid(@leader, 30_000)
    @leader.update_columns(deleted_at: Time.current, steam_id: nil)
  end

  teardown do
    players = [ @seller, @leader ].map(&:id)
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

  test "a forfeit that waits on the void either refuses or takes the whole released balance, and the money balances" do
    void = -> { Game::Market::VoidLead.new.call(player: Accounts::Player.find(@seller.id), listing_id: @listing.id) }
    forfeit = -> { Game::Market::ForfeitBalance.new.call(player: Accounts::Player.find(@leader.id)) }

    voiding, forfeiting = first_holding_the_lock(-> { void.call.value! }, forfeit)

    assert voiding
    assert_includes [ Dry::Monads::Success(100_000), Game::Market::ForfeitBalance::MARKET_PENDING ], forfeiting
    assert_equal [ 0, 0 ], figures(@leader) if forfeiting.success?
    assert Game::Market::ReconcileWallets.call.balanced?
  end
end
