require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::PlaceBidBuyNowTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @first = accounts_players(:moderator)
    @second = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    @settings = open_market!(commission_basis_points: 1_000)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, buy_now_price: 50_000, ends_at: 1.day.from_now)
    fund!(@first, 60_000)
    fund!(@second, 100_000)
  end

  def copies(player) = Game::Holding.find_by(player_id: player.id, card_season_id: @card.id)&.attributes&.values_at("quantity", "reserved")

  test "a maximum at the buy-now price buys at once from no leader" do
    answer = bid(@first, 80_000).value!

    assert_equal [ :buy_now, 50_000, nil ], [ answer.branch, answer.price, answer.minimum ]
    assert_equal [ "sold", 50_000, @first.id ], @listing.reload.attributes.values_at("status", "final_price", "leader_id")
    assert_equal [ 10_000, 0 ], figures(@first)
    assert_equal [ 0, 0 ], copies(@seller)
    assert_equal [ 1, 0 ], copies(@first)
  end

  test "the sale writes the edition price and the listing's average" do
    bid(@first, 50_000)

    assert_equal 50_000, @listing.reload.average_after_sale
    assert_equal [ 50_000, 1 ], Game::Market::EditionPrice.find_by!(card_season_id: @card.id).attributes.values_at("average", "sales_used")
  end

  test "the sale publishes one sold event and no bid event" do
    bid(@first, 50_000)

    assert_equal 1, events(Game::Market::AuctionSold).size
    assert_empty events(Game::Market::BidPlaced)
    data = events(Game::Market::AuctionSold).last.data
    assert_equal [ @first.id, 50_000, 0, nil, 0 ], data.values_at(:winner_id, :final_price, :surplus, :outbid_player_id, :outbid_released)
  end

  test "a leader raising into the buy-now price holds only the difference" do
    fund!(@first, 40_000)
    bid(@first, 30_000)

    answer = bid(@first, 60_000).value!

    assert_equal [ :buy_now, [ 50_000, 0 ] ], [ answer.branch, figures(@first) ]
    assert_equal [ @first.id, 50_000, 50_000 ], @listing.reload.attributes.values_at("leader_id", "leader_maximum", "current_price")
    assert_equal [ 30_000, 20_000 ], Game::Market::LedgerEntry.where(player_id: @first.id, kind: "hold").order(:id).pluck(:committed_delta)
  end

  test "a buy-now over another leader releases them in the same post and names them" do
    bid(@first, 30_000)

    bid(@second, 50_000)

    assert_equal [ 60_000, 0 ], figures(@first)
    assert_equal [ 50_000, 0 ], figures(@second)
    data = events(Game::Market::AuctionSold).last.data
    assert_equal [ @first.id, 30_000 ], data.values_at(:outbid_player_id, :outbid_released)
    assert_equal 1, Game::Market::LedgerEntry.where(listing_id: @listing.id, kind: %w[release purchase]).pluck(:created_at).uniq.size
  end

  test "a settled listing has no leading bid: the winner won, the others lost" do
    bid(@first, 30_000)
    bid(@second, 25_000)
    bid(@second, 50_000)

    assert_equal [ "lost" ], outcomes(@first)
    assert_equal %w[beaten won], outcomes(@second)
    assert_empty Game::Market::Bid.where(listing_id: @listing.id, outcome: "leading")
  end

  test "the winner's allocation and tiers are settled as a close does" do
    received = []
    receiver = Object.new
    receiver.define_singleton_method(:call) { |player:, season:| received << player.id and Dry::Monads::Success([]) }

    Game::ReceiveSeasonAllocation.stub(:new, receiver) { bid(@first, 50_000) }

    assert_equal [ @first.id ], received
  end

  test "the ledger reconciles after a buy-now" do
    destroyed = Game::Market::ReconcileWallets.call.destroyed
    bid(@first, 30_000)

    bid(@second, 50_000)

    assert_equal destroyed + 5_000, Game::Market::ReconcileWallets.call.destroyed
    assert Game::Market::ReconcileWallets.call.balanced?
  end

  test "a buy-now is refused for the seller and for a short balance" do
    fund!(@seller, 80_000)
    poor = Accounts::Player.create!(steam_id: "76561197960299999", persona_name: "Poor")
    fund!(poor, 49_999)

    nothing_changes { assert_equal :own_listing, bid(@seller, 50_000).failure }
    nothing_changes { assert_equal :more_than_available, bid(poor, 60_000).failure }
  end

  test "a closed listing sold by buy-now cannot be closed again" do
    bid(@first, 50_000)
    @listing.update_columns(ends_at: 1.minute.ago)

    assert_equal :listing_not_closable, Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id).failure
  end
end
