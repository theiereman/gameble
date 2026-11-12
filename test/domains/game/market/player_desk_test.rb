require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::PlayerDeskTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @player = accounts_players(:moderator)
    @rival = accounts_players(:administrator)
    @seller = accounts_players(:player)
    @cards = %i[common_card_one uncommon_card_one rare_card_one].map { catalog_card_seasons(it) }
    open_market!(first_opened_at: 1.day.ago)
  end

  def desk = Game::Market::PlayerDesk.call(@player)

  test "a player with no PiCoins, no bid and no sale is a newcomer" do
    assert_predicate desk, :newcomer?
  end

  test "it counts the bids outbid and led, the sales and those with an offer" do
    [ @player, @rival ].each { fund!(it, 200_000) }
    led = listing!(seller: @seller, card_season: @cards[0], starting_price: 20_000)
    lost = listing!(seller: @seller, card_season: @cards[1], starting_price: 20_000)
    assert bid(@player, 30_000, led).success?
    assert bid(@player, 30_000, lost).success?
    assert bid(@rival, 50_000, lost).success?
    listing!(seller: @player, card_season: @cards[2])
    offered = listing!(seller: @player, card_season: @cards[0])
    assert bid(@rival, 2_000, offered).success?

    assert_equal [ 1, 1, 2, 1 ], desk.to_h.values_at(:outbid, :leading, :selling, :selling_with_offers)
    assert_not_predicate desk, :newcomer?
  end

  test "spare copies leave one copy of each card and what is reserved" do
    hold(@player, @cards[0].id, 3)
    hold(@player, @cards[1].id, 4, reserved: 2)
    hold(@player, @cards[2].id, 1)

    assert_equal 4, desk.spare_copies
  end
end
