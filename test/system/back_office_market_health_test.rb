require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_snapshots"
require_relative "../support/steam_sign_in"

# Staff read the economy's health from the nightly snapshots: each indicator in plain words, the last reconciliation and the oldest listing due.
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
      snapshot!(@yesterday - ago, created: 10_000, destroyed: 5_600, circulation: 400_000, picoins_per_active_player: 12_300,
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
    assert_text "PAGE NOT FOUND"
  end
end
