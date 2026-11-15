require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::BidStandsTest < ActiveSupport::TestCase
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @bidder = accounts_players(:moderator)
    @rival = accounts_players(:administrator)
    @settings = open_market!(first_opened_at: 1.day.ago)
    [ @bidder, @rival ].each { fund!(it, 200_000) }
    @listing = listing!(seller: @seller, card_season: catalog_card_seasons(:common_card_one), starting_price: 20_000)
  end

  def stands(player = @bidder, tokens: [ @listing.token ]) = Game::Market::BidStands.call(player, tokens:)

  test "a listing the player leads stands leading with their maximum" do
    assert bid(@bidder, 30_000).success?

    assert_equal Game::Market::BidStands::Stand.new(status: :leading, amount: 30_000), stands.fetch(@listing.token)
  end

  test "a listing where a rival leads stands outbid with the smallest offer that takes the lead" do
    assert bid(@bidder, 30_000).success?
    assert bid(@rival, 50_000).success?

    price = @listing.reload.current_price
    to_beat = Game::Market::AuctionMath.minimum_bid(price:, starting_price: 20_000, basis_points: @settings.increment_basis_points)
    assert_equal Game::Market::BidStands::Stand.new(status: :outbid, amount: to_beat), stands.fetch(@listing.token)
    assert_operator to_beat, :>, price
  end

  test "listings without a bid of the player, closed listings and other tokens stand nowhere" do
    other = listing!(seller: @seller, card_season: catalog_card_seasons(:rare_card_one), starting_price: 20_000)
    assert bid(@rival, 30_000, other).success?
    closed = listing!(seller: @seller, card_season: catalog_card_seasons(:uncommon_card_one), starting_price: 20_000)
    assert bid(@bidder, 30_000, closed).success?
    closed.update_columns(status: "sold", sold_at: 1.minute.ago, final_price: 20_000)

    assert_empty stands(tokens: [ @listing.token, other.token, closed.token ])
  end

  test "an anonymous visitor or an empty page asks nothing" do
    assert_no_queries { assert_empty stands(nil) }
    assert_no_queries { assert_empty stands(tokens: []) }
  end

  test "a page of listings costs the same few queries whatever their number" do
    listings = %i[rare_card_one uncommon_card_one portal_one].map { listing!(seller: @seller, card_season: catalog_card_seasons(it), starting_price: 20_000) }
    listings.each { assert bid(@bidder, 30_000, it).success? }

    assert_queries_count(2) { assert_equal 3, stands(tokens: listings.map(&:token)).size }
  end
end
