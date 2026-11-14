require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/steam_sign_in"

class MarketFiltersSystemTest < ApplicationSystemTestCase
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    open_market!(first_opened_at: 1.day.ago)
    seller = accounts_players(:player)
    listing!(seller:, card_season: catalog_card_seasons(:common_card_one), starting_price: 1_300)
    listing!(seller:, card_season: catalog_card_seasons(:rare_card_one), starting_price: 9_000)
    listing!(seller:, card_season: catalog_card_seasons(:portal_one), starting_price: 25_000)
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
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
    assert_current_path(/max_price=10%2C000/)
    assert_selector ".listing-tile", count: 1
    assert_field "max_price", with: "10,000"

    click_on "Price, low to high"
    assert_selector ".market-screen__sort[aria-current=true]", text: "Price, low to high"
    assert_selector ".listing-tile", count: 1
    assert_field "max_price", with: "10,000"

    fill_in "max_price", with: "100"
    find("button", text: /apply/i).click
    assert_selector ".market-screen__empty", text: "No listings match these filters."
    assert_no_selector ".listing-tile"
  end

  test "a player hides their own sales, keeps them hidden through a sort, and shows them again" do
    listing!(seller: accounts_players(:moderator), card_season: catalog_card_seasons(:uncommon_card_one), starting_price: 3_400)
    sign_in_through_the_site(accounts_players(:player))

    visit market_path(locale: :en)
    assert_selector ".listing-tile", count: 4

    find(".market-filters__mine", text: /hide my sales/i).click
    assert_selector ".listing-tile", count: 1
    assert_checked_field "hide_mine", visible: :all

    click_on "Price, low to high"
    assert_selector ".market-screen__sort[aria-current=true]", text: "Price, low to high"
    assert_selector ".listing-tile", count: 1

    find(".market-filters__mine", text: /hide my sales/i).click
    assert_selector ".listing-tile", count: 4
  end
end
