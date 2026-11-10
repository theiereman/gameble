require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

class PlayerExportMarketTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @bidder = accounts_players(:moderator)
    @rival = accounts_players(:administrator)
    @rival.update!(persona_name: "Rival")
    @card = catalog_card_seasons(:common_card_one)
    open_market!(first_opened_at: 1.day.ago)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @bidder, @rival ].each { fund!(it, 200_000) }
    assert bid(@bidder, 30_000).success?
    assert bid(@rival, 77_777).success?
  end

  def export(player) = PlayerExport.new(player, locale: :en, now: Time.utc(2026, 11, 10, 9)).to_h

  test "a bidder's file holds the wallet, the ledger entries and the bids with their own maximums, by listing token" do
    hash = export(@bidder)

    assert_equal({ available: 200_000, committed: 0 }, hash[:wallet])
    assert_equal [ 30_000 ], hash[:bids].map { it[:maximum] }
    bid = hash[:bids].sole
    assert_equal [ @listing.token, "outbid" ], [ bid[:listing], bid[:outcome] ]
    assert_equal %i[listing maximum priceAfter outcome placedAt], bid.keys
    assert_equal %w[mint hold release], hash[:picoinEntries].map { it[:kind] }
    assert_equal [ nil, @listing.token, @listing.token ], hash[:picoinEntries].map { it[:listing] }
    assert_equal %i[kind availableDelta committedDelta listing at], hash[:picoinEntries].first.keys
    assert_empty hash[:listings]
  end

  test "a seller's file holds the listing without its leader or the leader's maximum" do
    hash = export(@seller)

    listing = hash[:listings].sole
    assert_equal [ @listing.token, { slug: "tin-soldier", season: 1 }, "open", 20_000 ], listing.values_at(:token, :card, :status, :startingPrice)
    assert_equal %i[token card status startingPrice buyNowPrice currentPrice finalPrice durationHours listedAt endsAt soldAt], listing.keys
    assert_empty hash[:bids]
    assert_not_includes hash.to_json, "77777"
    assert_not_includes hash.to_json, @rival.token
    assert_not_includes hash.to_json, "Rival"
  end

  test "no file holds another player's maximum" do
    [ @bidder, @seller ].each { assert_not_includes export(it).to_json, "77777" }
    assert_equal [ 77_777 ], export(@rival)[:bids].map { it[:maximum] }
  end

  test "an account that never used the market exports a zero wallet and empty lists" do
    stranger = Accounts::Player.create!(steam_id: "76561197960287999", persona_name: "Nobody")

    hash = export(stranger)

    assert_equal({ available: 0, committed: 0 }, hash[:wallet])
    assert_equal [ [], [], [] ], hash.values_at(:picoinEntries, :listings, :bids)
  end
end
