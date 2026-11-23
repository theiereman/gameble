require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_orders"

class Game::Market::GroupedWantedTest < ActiveSupport::TestCase
  include MarketAuctions
  include MarketListings
  include MarketOrders
  include MarketSettings

  setup do
    @reader = accounts_players(:moderator)
    @seller = accounts_players(:player)
    open_market!
    fund!(@reader, 10_000)
    @rare = catalog_card_seasons(:rare_card_one)
    @common = catalog_card_seasons(:common_card_one)
    @epic = catalog_card_seasons(:portal_one)
  end

  def want(*card_seasons)
    orders = card_seasons.map { order!(@reader, it, 300) }
    Game::Market::RebuildWanted.new.call(player: @reader).value!
    orders
  end

  def noticed(card_season, created_at: Time.current, status: "open")
    listing = listing!(seller: @seller, card_season:, created_at:, status:)
    Game::Market::Notice.record(player_id: @reader.id, listing_id: listing.id, kind: "wanted", amount: 13)
    listing
  end

  def grouped = Game::Market::GroupedWanted.call(player: @reader, locale: :en)

  def read(at) = Game::MarkBellRead.new.call(player: @reader, keys: [ "wanted:grouped:anything" ], now: at).value!

  test "the cards still wanted on open listings are counted once each and unseen before any read" do
    want(@rare, @common)
    noticed(@rare, created_at: 2.hours.ago)
    noticed(@rare, created_at: 1.hour.ago)
    newest = noticed(@common, created_at: 30.minutes.ago)

    line = grouped
    assert_equal [ 2, false ], [ line.count, line.seen ]
    assert_in_delta newest.created_at, line.newest_at, 0.001
  end

  test "an ended listing, a card no longer wanted and a card listed above the player's order are left out" do
    order, = want(@rare, @epic)
    noticed(@common)
    noticed(@rare, status: "sold")
    listing = noticed(@epic)
    Game::Market::Notice.record(player_id: @reader.id, listing_id: listing!(seller: @seller, card_season: @rare, starting_price: 400).id,
      order_id: order.id, kind: "listed_above_order", amount: 400)

    line = grouped
    assert_equal [ 1, "Portal" ], [ line.count, line.card ]
  end

  test "no wanted card on sale is no line" do
    want(@rare)
    noticed(@rare, status: "cancelled")

    assert_nil grouped
  end

  test "the line is seen once read, and unseen again when a wanted card is listed after the read" do
    want(@rare, @common)
    noticed(@rare, created_at: 2.hours.ago)
    read(1.hour.ago)

    assert grouped.seen

    noticed(@common)

    assert_not grouped.seen
  end
end
