require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::BidSheetTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @leader = accounts_players(:moderator)
    @other = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(increment_basis_points: 500, soft_close_seconds: 300)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @leader, @other ].each { fund!(it, 100_000) }
  end

  def sheet(player) = Game::Market::BidSheet.call(token: @listing.token, player:)

  test "without a leader the minimum is the starting price and the figures are the bidder's" do
    result = sheet(@other)

    assert_equal [ 20_000, false, nil, 100_000, 20_000, 5 ],
      [ result.minimum, result.leading, result.own_maximum, result.available, result.current_price, result.soft_close_minutes ]
  end

  test "with a leader the minimum is one increment above the price" do
    bid(@leader, 30_000)

    assert_equal [ 21_000, false, nil ], sheet(@other).then { [ it.minimum, it.leading, it.own_maximum ] }
  end

  test "the leader reads their own maximum and a raising minimum" do
    bid(@leader, 30_000)
    result = sheet(@leader)

    assert_equal [ 30_001, true, 30_000, 70_000 ], [ result.minimum, result.leading, result.own_maximum, result.available ]
  end

  test "nobody else is given a maximum" do
    bid(@leader, 30_000)

    assert_not_includes sheet(@other).to_h.values, 30_000
  end

  test "a removed leader counts as no leader" do
    bid(@leader, 30_000)
    @leader.update_columns(banned_at: Time.current)

    assert_equal [ 20_000, false ], sheet(@other).then { [ it.minimum, it.leading ] }
  end

  test "there is no sheet for the seller, a visitor, a removed player, an ended or a due listing" do
    assert_nil sheet(@seller)
    assert_nil sheet(nil)
    assert_nil sheet(accounts_players(:banned))

    @listing.update_columns(ends_at: 1.minute.ago)
    assert_nil sheet(@other)

    @listing.update_columns(ends_at: 1.day.from_now, status: "sold")
    assert_nil sheet(@other)
  end

  test "the soft-close window is the listing's own version, in minutes" do
    open_market!(soft_close_seconds: 600)

    assert_equal 5, sheet(@other).soft_close_minutes
  end

  test "the unusual multiple is the current version's value" do
    assert_equal 3, sheet(@other).unusual_multiple

    open_market!(unusual_maximum_multiple: 5)

    assert_equal 5, sheet(@other).unusual_multiple
  end
end
