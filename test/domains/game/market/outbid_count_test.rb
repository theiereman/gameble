require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::OutbidCountTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @bidder = accounts_players(:moderator)
    @rival = accounts_players(:administrator)
    @cards = %i[common_card_one uncommon_card_one rare_card_one].map { catalog_card_seasons(it) }
    open_market!(first_opened_at: 1.day.ago)
    [ @bidder, @rival ].each { fund!(it, 200_000) }
  end

  def count(player = @bidder) = Game::Market::OutbidCount.call(player)

  def listing(card = @cards[0]) = listing!(seller: @seller, card_season: card, starting_price: 20_000)

  test "a player who never bid has none" do
    listing

    assert_equal 0, count
  end

  test "an auction the player leads is not counted" do
    mine = listing
    assert bid(@bidder, 30_000, mine).success?

    assert_equal 0, count
  end

  test "an auction led by another player after the player's bid is counted, one per listing" do
    first = listing(@cards[0])
    second = listing(@cards[1])
    [ first, second ].each { assert bid(@bidder, 30_000, it).success? }
    [ first, second ].each { assert bid(@rival, 50_000, it).success? }
    assert bid(@bidder, 35_000, first).success?

    assert_equal 2, count
    assert_equal 0, count(@rival)
  end

  test "a bid beaten at once counts, and a raise back to the lead takes the auction out" do
    mine = listing
    assert bid(@rival, 50_000, mine).success?
    assert bid(@bidder, 30_000, mine).success?
    assert_equal 1, count

    assert bid(@bidder, 60_000, mine).success?
    assert_equal 0, count
  end

  test "an ended, cancelled or voided auction is not counted" do
    ended = listing(@cards[0])
    voided = listing(@cards[1])
    assert bid(@bidder, 30_000, ended).success?
    assert bid(@rival, 50_000, ended).success?
    assert bid(@bidder, 30_000, voided).success?
    assert bid(@rival, 50_000, voided).success?
    Game::Market::Bid.where(listing_id: voided.id, player_id: @bidder.id).update_all(outcome: "voided")
    assert_equal 1, count

    ended.update_columns(status: "sold", sold_at: Time.current, final_price: 30_000)

    assert_equal 0, count
  end

  test "the seller's own listing is not counted" do
    mine = listing
    Game::Market::Bid.create!(listing: mine, player: @seller, maximum: 30_000, price_after: 20_000, outcome: "beaten")

    assert_equal 0, count(@seller)
  end

  test "the bidders of a listing are its public bidders, once each" do
    mine = listing
    assert bid(@bidder, 30_000, mine).success?
    assert bid(@bidder, 35_000, mine).success?
    assert bid(@rival, 50_000, mine).success?

    assert_equal [ @bidder.id, @rival.id ].sort, Game::Market::ListingBidders.call(mine.id).sort
  end
end
