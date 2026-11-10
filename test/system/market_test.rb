require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/market_listings"

# Before the first opening the market address shows the teaser; after it a visitor reads the listings and opens an Annonce.
class MarketTest < ApplicationSystemTestCase
  include MarketListings
  include MarketSettings

  setup do
    Game::Market::Settings.delete_all
    @seller = accounts_players(:player)
    @seller.update_columns(persona_name: "Alice")
  end

  test "the teaser shows until the first opening, then a visitor reads the listings, sorts them and opens an Annonce" do
    open_market!(open: false)
    visit market_path(locale: :en)
    assert_selector "h1", text: "The Brotherhood is building the market"

    open_market!(first_opened_at: 1.day.ago)
    cheap = listing!(seller: @seller, card_season: catalog_card_seasons(:common_card_one), starting_price: 1_300, hours: 12)
    listing!(seller: @seller, card_season: catalog_card_seasons(:rare_card_one), starting_price: 9_000, hours: 72)

    visit market_path(locale: :en)
    assert_selector "h1", text: "Market"
    assert_selector ".listing-tile", count: 2
    assert_equal "Tin Soldier", first(".listing-tile a")["aria-label"].split(",").first

    click_on "Price, high to low"
    assert_selector ".market-screen__sort[aria-current=true]", text: "Price, high to low"
    assert_equal "Blue Depths", first(".listing-tile a")["aria-label"].split(",").first

    find(".listing-tile a[href$='#{cheap.token}']").click
    assert_selector "h1#market-listing-heading", text: "Tin Soldier"
    assert_equal "market-listing-heading", page.evaluate_script("document.activeElement.id")
    assert_selector ".market-listing__price", text: "1,300"
    assert_selector ".market-listing__ends time"
    assert_selector ".market-listing__fact a", text: "Alice"
  end
end
