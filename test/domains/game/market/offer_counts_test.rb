require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::OfferCountsTest < ActiveSupport::TestCase
  include MarketListings
  include MarketSettings

  setup do
    open_market!
    @seller = accounts_players(:player)
    @bidder = accounts_players(:moderator)
    @first = listing!(seller: @seller, card_season: catalog_card_seasons(:common_card_one))
    @second = listing!(seller: @seller, card_season: catalog_card_seasons(:rare_card_one))
  end

  def add(listing, outcome)
    Game::Market::Bid.create!(listing:, player: @bidder, maximum: 5_000, price_after: 1_300, outcome:)
  end

  test "counts the public bids of each listing and ignores raises and voided rows" do
    %w[leading outbid beaten won lost].each { add(@first, it) }
    add(@first, "raise")
    add(@first, "voided")
    add(@second, "leading")

    counts = Game::Market::OfferCounts.call([ @first.id, @second.id ])

    assert_equal 5, counts[@first.id]
    assert_equal 1, counts[@second.id]
  end

  test "a listing with no bid reads zero" do
    assert_equal 0, Game::Market::OfferCounts.call([ @first.id ])[@first.id]
    assert_equal 0, Game::Market::OfferCounts.call([])[0]
  end

  test "only the asked listings are counted" do
    add(@second, "leading")

    assert_equal({}, Game::Market::OfferCounts.call([ @first.id ]).to_h)
  end
end
