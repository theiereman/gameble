require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/market"
require_relative "../../support/market_listings"
require_relative "../../support/market_snapshots"
require_relative "../../support/steam_sign_in"

module BackOffice
  class MarketHealthControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include MarketListings
    include MarketSettings
    include MarketSnapshots
    include SteamSignIn

    setup do
      clear_snapshots
      Game::Market::Settings.delete_all
      @settings = open_market!(first_opened_at: 10.days.ago, alert_destroyed_share_basis_points: 4_000, income_days_target_epic: BigDecimal("1.5"))
      @yesterday = Time.current.utc.to_date - 1
    end

    def week_of_snapshots
      7.times do |ago|
        snapshot!(@yesterday - ago, created: 10_000, destroyed_total: 5_600, forfeited: 200, circulation: 400_000, picoins_per_active_player: 12_300,
          median_daily_earnings: 8_000, average_price_epic: 12_000, top_share_basis_points: 2_500)
      end
    end

    test "staff read each indicator with its three lines, the reconciliation, the snapshot and the oldest due listing" do
      week_of_snapshots
      listing!(seller: accounts_players(:player), card_season: catalog_card_seasons(:common_card_one), ends_at: 15.minutes.ago)
      sign_in(accounts_players(:moderator))

      get back_office_market_health_path(locale: :en)

      assert_response :success
      assert_select "h1", "The economy's health"
      assert_select "[data-health-indicator]", 4
      assert_select "[data-health-indicator=destroyed_share][data-health-state=read]" do
        assert_select ".market-health__value", "56%"
        assert_select ".market-health__threshold", /Alert below 40%/
        assert_select ".market-health__line", 3
      end
      assert_select "[data-health-indicator=picoins_per_player] .market-health__value", "12.3k"
      assert_select "[data-health-indicator=top_share] .market-health__value", "25%"
      assert_select "[data-health-rarity=epic]" do
        assert_select "td", "1.5 d"
      end
      assert_select "[data-health-reconciliation]", /balanced/
      assert_select "[data-health-snapshot] .market-health__fact", 6
      assert_select "[data-health-snapshot]", /5,600 \(200 of them forfeited\)/
      assert_select "[data-health-oldest-due]", /15 minutes/
      assert_select "[style]", false
    end

    test "with no snapshot each indicator says it has not enough data" do
      sign_in(accounts_players(:moderator))

      get back_office_market_health_path(locale: :fr)

      assert_select "[data-health-state=no-data]", 4
      assert_select "[data-health-indicator] .market-health__no-data", text: "Pas encore assez de données", count: 4
      assert_select "[data-health-reconciliation]", /Pas encore assez de données/
      assert_select "[data-health-oldest-due]", /Aucune annonce/
    end

    test "a reconciliation that found a difference says so" do
      snapshot!(@yesterday, reconciliation_balanced: false, wallet_differences: 2, circulation_difference: -30)
      sign_in(accounts_players(:administrator))

      get back_office_market_health_path(locale: :en)

      assert_select ".market-health__difference", /2 wallets off.*-30 PiCoins/
    end

    test "both market pages lead to each other" do
      sign_in(accounts_players(:moderator))

      get back_office_market_health_path(locale: :en)
      assert_select "nav.market-navigation a[href='/en/back-office/market'][aria-current]", false
      assert_select "nav.market-navigation a[href='/en/back-office/market/health'][aria-current=page]"

      get back_office_market_path(locale: :en)
      assert_select "nav.market-navigation a[href='/en/back-office/market/health']"
      assert_select "nav.market-navigation a[href='/en/back-office/market'][aria-current=page]"
    end

    test "the page writes nothing" do
      week_of_snapshots
      sign_in(accounts_players(:moderator))

      assert_no_difference -> { Game::Market::DailySnapshot.count + Game::Market::Settings.count } do
        get back_office_market_health_path(locale: :en)
      end
    end

    test "a player and a visitor see an unknown address" do
      get back_office_market_health_path(locale: :en)
      assert_unknown_address

      sign_in(accounts_players(:player))
      get back_office_market_health_path(locale: :en)
      assert_unknown_address
    end

    def alerting_snapshot = snapshot!(@yesterday, created: 10_000, destroyed_total: 3_400, picoins_per_active_player: 1)

    test "an indicator past its threshold is framed and states the proposal, with both actions for an administrator" do
      alerting_snapshot
      sign_in(accounts_players(:administrator))

      get back_office_market_health_path(locale: :en)

      assert_select "[data-health-indicator=destroyed_share].market-health__tile--alert[data-controller=alert-ignore]" \
        "[data-alert-ignore-key-value=destroyed_share][data-alert-ignore-value-value='3400']" do
        assert_select "[data-health-alert=destroyed_share] .market-health__proposal", /raise the Rare stamp from 2,000 to 3,000.*minimum price rises to 8,900/
        assert_select "a[href='/en/back-office/market?prepare=destroyed_share#market-settings']", "Prepare this change"
        assert_select "button[data-action='alert-ignore#ignore']", "Ignore"
      end
      assert_select "[data-health-indicator=top_share].market-health__tile--alert", false
    end

    test "a moderator sees the alert and its proposal without the actions" do
      alerting_snapshot
      sign_in(accounts_players(:moderator))

      get back_office_market_health_path(locale: :fr)

      assert_select "[data-health-alert=destroyed_share] .market-health__proposal", /relever le timbre Rare/
      assert_select "[data-health-alert=destroyed_share] a", false
      assert_select "[data-health-alert=destroyed_share] button", false
      assert_select "[data-health-alert=destroyed_share]", /Seul un administrateur/
    end

    test "no alert on a tile whose last point is null" do
      snapshot!(@yesterday, created: 0, destroyed_total: 0)
      sign_in(accounts_players(:administrator))

      get back_office_market_health_path(locale: :en)

      assert_select "[data-health-alert]", false
      assert_select ".market-health__tile--alert", false
    end
  end
end
