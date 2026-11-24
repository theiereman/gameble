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

  test "a served or expired order is pushed to its owner, and each sale of a Confier validation to its buyer" do
    assert_equal [ { player_id: 2, order_id: 9 } ],
      MarketPushNotice.notices(Game::Market::OrderServed.new(data: { order_id: 9, buyer_id: 2, seller_id: 1, card_season_id: 5, price: 100 }))
    assert_equal [ { player_id: 2, order_id: 9 } ],
      MarketPushNotice.notices(Game::Market::OrderExpired.new(data: { order_id: 9, player_id: 2, card_id: 5, amount: 100 }))
    sales = [ { order_id: 9, buyer_id: 2, card_season_id: 5, price: 100 }, { order_id: 10, buyer_id: 3, card_season_id: 5, price: 90 } ]
    assert_equal [ { player_id: 2, order_id: 9 }, { player_id: 3, order_id: 10 } ],
      MarketPushNotice.notices(Game::Market::WantedChoicesApplied.with(seller_id: 1, sales:, listing_ids: [ 4 ], entrusted: []))
  end

  test "an order notification leads to the edition received, or to My orders once expired" do
    edition = Catalog::CardViews.call([ catalog_card_seasons(:portal_one).id ], locale: :en).values.sole
    line = Game::Market::OrderNoticeLines::Line.new(kind: :order_served, token: "ord", listing_token: nil, card: "Portal", edition:, other: nil,
      amount: 1_200, noticed_at: Time.current)
    served = MarketPushNotice.notification(line, locale: "fr")

    assert_equal [ "Ordre servi", "Votre ordre sur Portal est servi\u202f: la carte rejoint votre collection." ], [ served.title, served.body ]
    assert_equal({ path: "/fr/cards/#{edition.id}/seasons/#{edition.season_number}" }, served.data)
    expired = MarketPushNotice.notification(line.with(kind: :order_expired), locale: "en")
    assert_equal "Order expired", expired.title
    assert_match(/\AYour order on Portal expired\. Your 1,200 PiCoins are available again\.\z/, expired.body)
    assert_equal "/en/market/my-orders", expired.data[:path]
  end

  test "a listing pushes each converted order's owner, and the notification leads to the listing" do
    converted = [ { order_id: 9, owner_id: 2, listing_id: 7, price: 400, status: "bid" }, { order_id: 10, owner_id: 3, listing_id: 7, price: 350, status: "beaten" } ]

    assert_equal [ { player_id: 2, order_id: 9 }, { player_id: 3, order_id: 10 } ],
      MarketPushNotice.notices(Game::Market::CardListed.with(listing_id: 7, seller_id: 1, card_season_id: 5, converted:))
    assert_empty MarketPushNotice.notices(Game::Market::CardListed.with(listing_id: 7, seller_id: 1, card_season_id: 5))
    edition = Catalog::CardViews.call([ catalog_card_seasons(:portal_one).id ], locale: :en).values.sole
    line = Game::Market::OrderNoticeLines::Line.new(kind: :order_leads, token: "ord", listing_token: "lst", card: "Portal", edition:, other: nil,
      amount: 400, noticed_at: Time.current)

    leads = MarketPushNotice.notification(line, locale: "en")
    beaten = MarketPushNotice.notification(line.with(kind: :order_beaten), locale: "fr")

    assert_equal [ "Order leading", "/en/market/listings/lst" ], [ leads.title, leads.data[:path] ]
    assert_match(/\AYour order on Portal became a bid: it leads the auction up to 400 PiCoins\.\z/, leads.body)
    assert_equal [ "Ordre dépassé", "/fr/market/listings/lst" ], [ beaten.title, beaten.data[:path] ]
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
