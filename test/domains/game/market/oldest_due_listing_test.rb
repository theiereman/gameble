require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::OldestDueListingTest < ActiveSupport::TestCase
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    open_market!
    @card = catalog_card_seasons(:common_card_one)
  end

  test "nil when nothing is due" do
    listing!(seller: @seller, card_season: @card, ends_at: 1.hour.from_now)

    assert_nil Game::Market::OldestDueListing.call
  end

  test "whole seconds since the oldest due open listing ended" do
    now = Time.current
    listing!(seller: @seller, card_season: @card, ends_at: now - 90.seconds)
    listing!(seller: @seller, card_season: catalog_card_seasons(:portal_one), ends_at: now - 10.seconds)

    assert_equal 90, Game::Market::OldestDueListing.call(now:)
  end

  test "a closed listing does not count" do
    listing!(seller: @seller, card_season: @card, ends_at: 1.hour.ago, status: "cancelled")

    assert_nil Game::Market::OldestDueListing.call
  end
end
