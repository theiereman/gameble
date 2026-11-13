require "application_system_test_case"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/steam_sign_in"

# An administrator closes the market and reopens it; in between a player meets the suspended banner on Confier.
class MarketSuspensionTest < ApplicationSystemTestCase
  include Holdings
  include MarketSettings
  include SteamSignIn

  setup do
    Game::Market::Settings.delete_all
    @first_opened_at = 2.days.ago.change(usec: 0)
    open_market!(first_opened_at: @first_opened_at, terms_confirmed_at: @first_opened_at, odds_confirmed_at: @first_opened_at)
    @card = catalog_card_seasons(:common_card_one)
    hold(accounts_players(:player), @card.id, 2)
  end

  def sign_in_through_the_site(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def close_from_the_back_office
    visit back_office_market_path(locale: :en)
    within("#market-closing") do
      fill_in "Message in French", with: "Le marché est suspendu"
      fill_in "Message in English", with: "The market is suspended"
      click_on "Close the market"
    end
    assert_text "The market is closed and the announcement is on the banner."
  end

  test "an administrator closes the market, the player sees the banner, and reopening restores entrusting with the first opening kept" do
    sign_in_through_the_site(accounts_players(:administrator))
    close_from_the_back_office

    assert_no_selector "#market-closing"
    assert_selector "#market-opening", text: "Reopen the market"

    using_session(:player) do
      sign_in_through_the_site(accounts_players(:player))
      assert_selector "#announcement-banner", text: "The market is suspended"
      visit new_market_entrustment_path(locale: :en)
      assert_selector "#market-suspended-banner", text: "THE MARKET IS SUSPENDED"
      assert_button "Entrust", disabled: true
      find("#market-suspended-banner a", text: /back to the market/i).click
      assert_selector "h1", text: "Market"
    end

    within("#market-opening") do
      fill_in "Message in French", with: "Le marché rouvre"
      fill_in "Message in English", with: "The market reopens"
      check "The terms of the market are in force and players can read them."
      check "The odds of every draw are published and truthful."
      click_on "Reopen the market"
    end
    assert_text "The market is open and the announcement is on the banner."
    assert_equal @first_opened_at, Game::Market::CurrentSettings.call.first_opened_at

    using_session(:player) do
      visit new_market_entrustment_path(locale: :en)
      assert_no_selector "#market-suspended-banner"
      find(".entrust-cell[data-ref='#{@card.card.slug}:#{@card.season.number}'] .entrust-cell__toggle").click
      click_on "Entrust 1 copy"
      assert_selector ".entrust-result__copies", text: "1 copy entrusted"
    end
  end

  test "a moderator sees the closing control disabled" do
    sign_in_through_the_site(accounts_players(:moderator))
    visit back_office_market_path(locale: :en)

    within("#market-closing") { assert_button "Close the market", disabled: true }
  end
end
