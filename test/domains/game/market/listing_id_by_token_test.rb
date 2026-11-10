require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::ListingIdByTokenTest < ActiveSupport::TestCase
  include MarketListings
  include MarketSettings

  setup do
    open_market!
    @listing = listing!(seller: accounts_players(:player), card_season: catalog_card_seasons(:common_card_one))
  end

  test "a known token gives the id" do
    assert_equal @listing.id, Game::Market::ListingIdByToken.call(@listing.token)
  end

  test "an unknown or blank token gives nothing" do
    assert_nil Game::Market::ListingIdByToken.call("nope")
    assert_nil Game::Market::ListingIdByToken.call(nil)
  end
end
