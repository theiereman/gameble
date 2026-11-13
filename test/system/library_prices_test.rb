require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/steam_sign_in"

class LibraryPricesSystemTest < ApplicationSystemTestCase
  include MarketSettings
  include SteamSignIn

  setup do
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago)
    { common_card_one: 1_000, uncommon_card_one: 4_000, rare_card_one: 9_000, portal_one: 30_000 }.each do |name, average|
      Game::Market::EditionPrice.create!(card_season_id: catalog_card_seasons(name).id, average:, sales_used: 5)
    end
    mock_steam_sign_in(accounts_players(:moderator).steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def titles = all(".collection-slot .card__title").map { it.text.downcase }

  test "sorting by price descending puts the dearest first and the no-sale cards last, and a range keeps the cards inside it with their prices" do
    visit library_cards_path(locale: :en)
    assert_no_selector ".collection-slot__price"

    find("a.filter-row__pastille[href='#filters-price']").click
    within("#filters-price") { find(".filter-chip__text", text: /\AAverage price, highest first\z/i).click }

    assert_selector ".collection-slot__price", count: 5
    assert_equal "portal", titles.first
    assert_equal "golden crown", titles.last
    assert_selector ".collection-slot:first-child .collection-slot__price .picoin-amount__figure", text: "30k"
    assert_selector ".collection-slot:last-child .collection-slot__price", text: /no sale/i

    within("#filters-price") do
      fill_in "Minimum price", with: "3000"
      fill_in "Maximum price", with: "10000"
      find_field("Maximum price").send_keys(:tab)
    end

    assert_selector ".collection-slot", count: 2
    assert_equal [ "blue depths", "green hills" ], titles
    assert_selector ".collection-slot__price", count: 2
  end
end
