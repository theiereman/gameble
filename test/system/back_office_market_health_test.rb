require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_snapshots"
require_relative "../support/steam_sign_in"

class BackOfficeMarketHealthTest < ApplicationSystemTestCase
  include MarketListings
  include MarketSettings
  include MarketSnapshots
  include SteamSignIn

  setup do
    clear_snapshots
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 10.days.ago, alert_destroyed_share_basis_points: 4_000)
    @yesterday = Time.current.utc.to_date - 1
  end

  teardown { clear_snapshots }

  def visit_health_as(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit back_office_market_health_path(locale: :en)
  end

  test "with a week of snapshots staff read the four indicators with their three lines and the day's figures" do
    7.times do |ago|
      snapshot!(@yesterday - ago, created: 10_000, destroyed_total: 5_600, circulation: 400_000, picoins_per_active_player: 12_300,
        median_daily_earnings: 8_000, average_price_epic: 12_000, top_share_basis_points: 2_500)
    end
    listing!(seller: accounts_players(:player), card_season: catalog_card_seasons(:common_card_one), ends_at: 15.minutes.ago)

    visit_health_as(accounts_players(:moderator))

    assert_selector "[data-health-indicator]", count: 4
    within("[data-health-indicator=destroyed_share]") do
      assert_text "56%"
      assert_text "What is happening"
      assert_text "Why it matters"
      assert_text "What to do"
    end
    within("[data-health-snapshot]") { assert_text "In circulation" }
    assert_selector "[data-health-reconciliation]", text: "balanced"
    assert_selector "[data-health-oldest-due]", text: "15 minutes"
  end

  test "with no snapshot each indicator says it has not enough data" do
    visit_health_as(accounts_players(:moderator))

    assert_selector "[data-health-state=no-data]", count: 4
    assert_text "Not enough data yet", minimum: 4
  end

  test "a player gets the back-office refusal" do
    visit_health_as(accounts_players(:player))

    assert_no_selector "[data-health-indicator]"
    assert_text "No route matches"
  end

  def alerting_snapshot(destroyed: 3_400) = snapshot!(@yesterday, created: 10_000, destroyed_total: destroyed)

  test "an administrator prepares the change, finds it prefilled with focus on the first field, and leaves without saving" do
    alerting_snapshot
    version = Game::Market::CurrentSettings.call
    visit_health_as(accounts_players(:administrator))

    within("[data-health-alert=destroyed_share]") do
      assert_text "raise the Rare stamp from 2,000 to 3,000"
      click_on "Prepare this change"
    end

    assert_selector "[data-market-settings-prepared]"
    assert_field "market_settings[stamp_rare]", with: "3000", focused: true
    assert_field "market_settings[minimum_price_rare]", with: "8900"
    visit back_office_market_health_path(locale: :en)

    assert_selector "[data-health-alert=destroyed_share]"
    assert_equal version, Game::Market::CurrentSettings.call
  end

  test "ignoring an alert hides it until the indicator's value changes" do
    alerting_snapshot
    visit_health_as(accounts_players(:administrator))

    within("[data-health-alert=destroyed_share]") { click_on "Ignore" }

    assert_no_selector "[data-health-alert=destroyed_share]", visible: :visible
    visit back_office_market_health_path(locale: :en)
    assert_no_selector "[data-health-alert=destroyed_share]", visible: :visible

    Game::Market::DailySnapshot.connection.execute("UPDATE game_market_daily_snapshots SET destroyed_total = 3500")
    visit back_office_market_health_path(locale: :en)
    assert_selector "[data-health-alert=destroyed_share]"
  end

  test "a moderator sees the alert without its actions" do
    alerting_snapshot
    visit_health_as(accounts_players(:moderator))

    assert_selector "[data-health-alert=destroyed_share]"
    assert_no_link "Prepare this change"
    assert_no_button "Ignore"
  end
end
