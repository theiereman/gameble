require "application_system_test_case"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/steam_sign_in"

# An administrator opens the market from the back-office with both confirmations and an announcement; a moderator only reads the page.
class BackOfficeMarketTest < ApplicationSystemTestCase
  include Holdings
  include MarketSettings
  include SteamSignIn

  setup do
    Game::Market::Settings.delete_all
    close_market!
  end

  def sign_in_through_the_site(player)
    sign_in_browser(player.steam_id)
    visit back_office_market_path(locale: :en)
  end

  test "an administrator opens the market and the announcement shows on the banner" do
    sign_in_through_the_site(accounts_players(:administrator))

    within("#market-opening") do
      fill_in "Message in French", with: "Le marché est ouvert"
      fill_in "Message in English", with: "The market is open"
      check "The terms of the market are in force and players can read them."
      check "The odds of every draw are published and truthful."
      click_on "Open the market"
    end

    assert_text "The market is open and the announcement is on the banner."
    assert_selector "[data-market-state=open]"
    assert_no_selector "#market-opening"
    assert Game::Market::MarketState.call.open?

    visit home_path(locale: :en)
    assert_selector "#announcement-banner", text: "The market is open"
  end
end
