require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/second_season"

class MarketAveragePriceSystemTest < ApplicationSystemTestCase
  include SteamSignIn
  include Holdings
  include MarketListings
  include MarketSettings
  include SecondSeason

  setup do
    @player = accounts_players(:player)
    @first = catalog_card_seasons(:portal_one)
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago)
    season, = publish_second_season(@player, held: [])
    @second = Catalog::CardSeason.find_by!(card_id: @first.card_id, season_id: season.id)
    Game::Market::EditionPrice.create!(card_season_id: @first.id, average: 15_000, sales_used: 5)
    Game::Market::EditionPrice.create!(card_season_id: @second.id, average: 40_000, sales_used: 3)
    hold(@player, @first.id, 1)
    hold(@player, @second.id, 1)
    mock_steam_sign_in(@player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "a player with two editions sees both prices in EDITIONS, the price on the Annonce, and the form's price follows the chosen cell" do
    visit card_season_path(locale: :en, slug: "portal", number: 2)
    within(".card-detail__editions") do
      assert_selector "li", text: "S1"
      assert_selector ".picoin-amount__figure", text: "15k"
      assert_selector ".picoin-amount__figure", text: "40k"
    end

    listing = listing!(seller: accounts_players(:moderator), card_season: @first, starting_price: 20_000)
    visit market_listing_path(locale: :en, token: listing.token)
    assert_selector ".market-listing__fact--price .picoin-amount__figure", text: "15,000"
    assert_selector ".market-listing__fact--price .average-price__basis", text: "Based on 5 sales"

    visit new_market_sale_path(locale: :en)
    first_cell = find("[role=option][data-season='1']")
    second_cell = find("[role=option][data-season='2']")
    first_cell.click
    assert_selector ".sale-price .picoin-amount__figure", text: "15,000"
    second_cell.click
    assert_selector ".sale-price .picoin-amount__figure", text: "40,000"
    assert_selector ".sale-price .average-price__basis", text: "Based on 3 sales"
  end
end
