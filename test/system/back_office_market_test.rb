require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/steam_sign_in"

# An administrator opens the market from the back-office with both confirmations and an announcement; a moderator only reads the page.
class BackOfficeMarketTest < ApplicationSystemTestCase
  include MarketSettings
  include SteamSignIn

  setup do
    Game::Market::Settings.delete_all
    close_market!
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit back_office_market_path(locale: :en)
  end

  test "an administrator opens the market and the announcement shows on the banner" do
    sign_in_through_the_site(accounts_players(:administrator))

    fill_in "Message in French", with: "Le marché est ouvert"
    fill_in "Message in English", with: "The market is open"
    check "The terms of the market are in force and players can read them."
    click_on "Open the market"

    assert_text "The market is open and the announcement is on the banner."
    assert_selector "[data-market-state=open]"
    assert_selector "#announcement-banner", text: "The market is open"
    assert_no_button "Open the market"
    assert Game::Market::MarketState.call.open?
  end

  test "a missing confirmation opens nothing and names itself" do
    sign_in_through_the_site(accounts_players(:administrator))

    fill_in "Message in French", with: "Le marché est ouvert"
    fill_in "Message in English", with: "The market is open"
    check "The terms of the market are in force and players can read them."
    click_on "Open the market"

    assert_selector "[data-market-opening-refusal]", text: "odds"
    assert_field "Message in English", with: "The market is open"
    assert_not Game::Market::MarketState.call.open?
  end

  test "a moderator reads the section with every control disabled" do
    sign_in_through_the_site(accounts_players(:moderator))

    assert_selector "[data-market-opening-reason]"
    assert_field "Message in English", disabled: true
    assert_button "Open the market", disabled: true
  end
end
