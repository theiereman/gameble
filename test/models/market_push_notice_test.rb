require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

class MarketPushNoticeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
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
    open_market!(increment_basis_points: 500, soft_close_seconds: 180)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @first, @second ].each { fund!(it, 100_000) }
  end

  def pushed = enqueued_jobs.select { it[:job] == MarketPushNoticeJob }.flat_map { it[:args].first }.map { it.symbolize_keys.slice(:player_id, :listing_id) }

  test "taking the lead notifies the outbid player once the bid commits, and a first bid notifies nobody" do
    bid(@first, 30_000)
    assert_empty pushed

    bid(@second, 40_000)
    assert_equal [ { player_id: @first.id, listing_id: @listing.id } ], pushed
  end

  test "a raise by the leader and a bid beaten at once notify nobody" do
    bid(@first, 30_000)
    bid(@first, 35_000)
    bid(@second, 25_000)

    assert_empty pushed
  end

  test "each outcome names the players it concerns" do
    data = { listing_id: 7, seller_id: 1, winner_id: 2, leader_id: 3 }

    assert_equal [ { player_id: 2, listing_id: 7 }, { player_id: 1, listing_id: 7 } ], MarketPushNotice.notices(Game::Market::AuctionSold.new(data:))
    assert_equal [ { player_id: 1, listing_id: 7 } ], MarketPushNotice.notices(Game::Market::AuctionUnsold.new(data:))
    assert_equal [ { player_id: 1, listing_id: 7 } ], MarketPushNotice.notices(Game::Market::LeadVoided.new(data:))
    assert_equal [ { player_id: 3, listing_id: 7 } ], MarketPushNotice.notices(Game::Market::ListingWithdrawn.new(data:))
    assert_empty MarketPushNotice.notices(Game::Market::ListingWithdrawn.new(data: { listing_id: 7, leader_id: nil }))
  end

  test "the notification is written in the device's locale and leads to the listing, or to the sales for what concerns the seller" do
    line = Game::Market::MarketNotices::Line.new(kind: :won, token: "abc", card: "Portal", other: nil, amount: 1_200, noticed_at: Time.current)
    won = MarketPushNotice.notification(line, locale: "fr")

    assert_equal "Enchère remportée", won.title
    assert_match(/\AVous avez remporté Portal pour 1\p{Space}200\p{Space}PiCoins\.\z/, won.body)
    assert_equal({ path: "/fr/market/listings/abc" }, won.data)
    assert_equal "/en/market/my-sales", MarketPushNotice.notification(line.with(kind: :sold), locale: "en").data[:path]
  end
end
