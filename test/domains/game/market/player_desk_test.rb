require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"
require_relative "../../../support/market_bidding"

class Game::Market::PlayerDeskTest < ActiveSupport::TestCase
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
  end
end
