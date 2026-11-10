require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/market_listings"

class MarketFiltersSystemTest < ApplicationSystemTestCase
  include MarketListings
  include MarketSettings

  setup do
    open_market!(first_opened_at: 1.day.ago)
    seller = accounts_players(:player)
    listing!(seller:, card_season: catalog_card_seasons(:common_card_one), starting_price: 1_300)
    listing!(seller:, card_season: catalog_card_seasons(:rare_card_one), starting_price: 9_000)
    listing!(seller:, card_season: catalog_card_seasons(:portal_one), starting_price: 25_000)
  end

  test "a visitor searches, filters by rarity, season and price, sorts and reads the empty line" do
    visit market_path(locale: :en)
    assert_selector ".listing-tile", count: 3

    fill_in "q", with: "blue"
    find("#market-search").send_keys(:enter)
    assert_selector ".listing-tile", count: 1
    assert_selector ".listing-tile a[aria-label^='Blue Depths']"

    visit market_path(locale: :en)
    find("summary", text: /filters/i).click
    find(".filter-chip", text: /\Arare\z/i).click
    assert_selector ".listing-tile", count: 1
    assert_selector "details[open]"
    find(".filter-chip", text: /season 1/i).click
    assert_selector ".listing-tile", count: 1
    fill_in "max_price", with: "10000"
    find("button", text: /apply/i).click
    assert_selector ".listing-tile", count: 1
    assert_field "max_price", with: "10000"

    click_on "Price, low to high"
    assert_selector ".market-screen__sort[aria-current=true]", text: "Price, low to high"
    assert_selector ".listing-tile", count: 1
    assert_field "max_price", with: "10000"

    fill_in "max_price", with: "100"
    find("button", text: /apply/i).click
    assert_selector ".market-screen__empty", text: "No listings match these filters."
    assert_no_selector ".listing-tile"
  end
end
