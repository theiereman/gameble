require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::BidHistoryTest < ActiveSupport::TestCase
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

  def history(viewer = nil) = Game::Market::BidHistory.call(token: @listing.token, viewer:)

  def worked_example
    bid(@first, 30_000)
    bid(@second, 25_000)
    @listing.update_columns(ends_at: 1.minute.from_now)
    bid(@second, 40_000)
  end

  test "an unknown token reads nothing" do
    assert_equal [], Game::Market::BidHistory.call(token: "nope", viewer: nil)
  end

  test "a listing with no bid holds only its creation line" do
    lines = history

    assert_equal [ :created ], lines.map(&:kind)
    assert_equal @seller, lines.first.player
  end

  test "lines run newest first with the extension above the bid that caused it and the creation last" do
    worked_example

    lines = history

    assert_equal %i[extension bid bid bid created], lines.map(&:kind)
    assert_equal [ 31_500, 26_300, 20_000 ], lines.select { it.kind == :bid }.map(&:price)
    assert_equal [ @second, @second, @first ], lines.select { it.kind == :bid }.map(&:player)
    assert_not_nil lines.first.until
  end

  test "the open listing's leader is marked on the leading line only" do
    worked_example

    assert_equal [ true, false, false ], history.select { it.kind == :bid }.map(&:leading)
  end

  test "no line is marked once the listing is closed" do
    worked_example
    @listing.update_columns(status: "sold")

    assert history.none?(&:leading)
  end

  test "a raise line is visible to its owner alone" do
    bid(@first, 30_000)
    bid(@first, 35_000)

    assert_equal %i[bid created], history.map(&:kind)
    assert_equal %i[bid created], history(@second).map(&:kind)
    assert_equal %i[raise bid created], history(@first).map(&:kind)
    assert_equal @first, history(@first).first.player
  end

  test "a removed player is returned as a player whose name the component hides" do
    bid(@first, 30_000)
    @first.update_columns(banned_at: Time.current)

    assert history.find { it.kind == :bid }.player.removed?
  end

  test "a voided line is visible to every viewer and carries no player" do
    bid(@first, 30_000)
    Game::Market::Bid.create!(listing: @listing, player: @first, maximum: 30_000, price_after: 20_000, outcome: "voided")

    [ nil, @second, @first ].each do |viewer|
      lines = history(viewer)
      assert_equal %i[voided bid created], lines.map(&:kind)
      assert_nil lines.first.player
    end
  end

  test "no statement selects a maximum from the bids" do
    worked_example
    statements = []
    subscriber = ->(*, payload) { statements << payload[:sql] }

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { history(@first) }

    bids = statements.select { it.include?("game_market_bids") }
    assert_not_empty bids
    assert bids.none? { it.include?("maximum") }
  end

  test "a bid beaten at once by the leader's maximum is marked as such, the leader keeping the lead" do
    bid(@first, 30_000)
    bid(@second, 30_000)

    bids = history.select { it.kind == :bid }
    assert_equal [ @second, @first ], bids.map(&:player)
    assert_equal [ true, false ], bids.map(&:beaten)
    assert_equal [ false, true ], bids.map(&:leading)
  end
end
