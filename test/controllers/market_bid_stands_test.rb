require "test_helper"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"
require_relative "../support/steam_sign_in"

# Each tile of the market tells the signed-in bidder where they stand: leading with their maximum, or outbid with the
# smallest offer that takes the lead back.
class MarketBidStandsTest < ActionDispatch::IntegrationTest
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    @settings = open_market!(first_opened_at: 1.day.ago)
    @player = accounts_players(:player)
    @rival = accounts_players(:administrator)
    seller = accounts_players(:moderator)
    [ @player, @rival ].each { fund!(it, 200_000) }
    @leading, @outbid, @untouched = %i[common_card_one rare_card_one portal_one].each_with_index.map do |card, index|
      listing!(seller:, card_season: catalog_card_seasons(card), starting_price: 20_000, hours: 12 + index)
    end
    assert bid(@player, 30_000, @leading).success?
    assert bid(@player, 25_000, @outbid).success?
    assert bid(@rival, 40_000, @outbid).success?
  end

  test "the tiles the player bid on show whether they lead, with their maximum or the offer to beat" do
    sign_in(@player)

    get market_path(locale: :fr)

    assert_response :success
    assert_select ".listing-tile__stand--leading", /EN TÊTE\s*max\s*#{compact(30_000)}/
    assert_select ".listing-tile__stand--outbid", /DÉPASSÉ\s*mini\s*#{compact(to_beat)}/
    assert_select ".listing-tile__stand", 2
    assert_select ".listing-tile__link[aria-label*='vous êtes en tête avec un maximum de']", 1
    assert_select ".listing-tile__link[aria-label*='votre offre est dépassée']", 1
  end

  test "a visitor and a player without bids see no stand" do
    get market_path(locale: :en)
    assert_select ".listing-tile__stand", 0

    sign_in(accounts_players(:moderator))
    get market_path(locale: :en)
    assert_select ".listing-tile__stand", 0
  end

  def compact(amount) = ApplicationController.helpers.picoins(amount, compact: true)

  def to_beat
    Game::Market::AuctionMath.minimum_bid(price: @outbid.reload.current_price, starting_price: 20_000, basis_points: @settings.increment_basis_points)
  end
end
