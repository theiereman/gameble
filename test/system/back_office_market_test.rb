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
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit back_office_market_path(locale: :en)
  end

  test "an administrator opens the market and the announcement shows on the banner" do
    sign_in_through_the_site(accounts_players(:administrator))

    within("#market-opening") do
      fill_in "Message in French", with: "Le marché est ouvert"
      fill_in "Message in English", with: "The market is open"
      check "The terms of the market are in force and players can read them."
      click_on "Open the market"
    end

    assert_text "The market is open and the announcement is on the banner."
    assert_selector "[data-market-state=open]"
    assert_selector "#announcement-banner", text: "The market is open"
    assert_no_selector "#market-opening"
    assert Game::Market::MarketState.call.open?
  end

  test "a missing confirmation opens nothing and names itself" do
    sign_in_through_the_site(accounts_players(:administrator))

    within("#market-opening") do
      fill_in "Message in French", with: "Le marché est ouvert"
      fill_in "Message in English", with: "The market is open"
      check "The terms of the market are in force and players can read them."
      click_on "Open the market"
    end

    assert_selector "[data-market-opening-refusal]", text: "odds"
    within("#market-opening") { assert_field "Message in English", with: "The market is open" }
    assert_not Game::Market::MarketState.call.open?
  end

  test "a moderator reads the section with every control disabled" do
    sign_in_through_the_site(accounts_players(:moderator))

    assert_selector "[data-market-opening-reason]"
    within("#market-opening") do
      assert_field "Message in English", disabled: true
      assert_button "Open the market", disabled: true
    end
    within("#market-settings") do
      assert_field "market-settings-stamp-rare", disabled: true
      assert_button "Save the settings", disabled: true
    end
  end

  test "an administrator raises the Rare stamp and minimum, a player sees the announcement and a form drawn before is refused" do
    open_market!
    card = catalog_card_seasons(:rare_card_one)
    hold(accounts_players(:player), card.id, 2)
    using_session(:player) do
      mock_steam_sign_in(accounts_players(:player).steam_id)
      visit home_path(locale: :en)
      click_steam_sign_in
      assert_signed_in
      visit new_market_entrustment_path(locale: :en)
      find(".entrust-cell[data-ref='#{card.card.slug}:#{card.season.number}'] .entrust-cell__toggle").click
    end
    sign_in_through_the_site(accounts_players(:administrator))

    within("#market-settings") do
      fill_in "market-settings-stamp-rare", with: "2500"
      fill_in "market-settings-minimum-price-rare", with: "8400"
      fill_in "Message in French", with: "Le timbre rare monte"
      fill_in "Message in English", with: "The Rare stamp goes up"
      click_on "Save the settings"
    end

    assert_text "The settings are saved and the announcement is on the banner."
    assert_equal 2_500, Game::Market::CurrentSettings.call.stamp_rare
    using_session(:player) do
      click_on "Entrust 1 copy"
      assert_text "The amounts changed while you were choosing"
      visit home_path(locale: :en)
      assert_selector "#announcement-banner", text: "The Rare stamp goes up"
    end
  end
end
