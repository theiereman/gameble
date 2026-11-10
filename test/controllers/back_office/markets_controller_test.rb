require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/market"
require_relative "../../support/market_snapshots"
require_relative "../../support/steam_sign_in"

module BackOffice
  class MarketsControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include MarketSettings
    include MarketSnapshots
    include SteamSignIn

    setup do
      Game::Market::Settings.delete_all
      close_market!
    end

    test "an administrator sees the state and the opening form of a market never opened" do
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :en)

      assert_response :success
      assert_select "h1", "The market"
      assert_select "[data-market-state=closed]", /never been opened/
      assert_select "form[action='/en/back-office/market/opening'][method=post]" do
        assert_select "input[type=checkbox][name=terms_confirmed]:not([disabled])"
        assert_select "input[type=checkbox][name=odds_confirmed]:not([disabled])"
        assert_select "textarea[name=message_fr]:not([disabled])"
        assert_select "button", "Open the market"
      end
      assert_select "[style]", false
    end

    test "after a first opening the same form reopens the market" do
      open_market!(first_opened_at: 2.days.ago)
      close_market!(first_opened_at: 2.days.ago)
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :fr)

      assert_select "[data-market-state=closed]", /suspendu/
      assert_select "button", "Rouvrir le marché"
    end

    test "an open market shows its state and the closing form, not the opening form" do
      open_market!(first_opened_at: Time.current)
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :en)

      assert_select "[data-market-state=open]"
      assert_select "form[action='/en/back-office/market/opening']", false
      assert_select "#market-closing form[action='/en/back-office/market/closing'][method=post]" do
        assert_select "input[type=hidden][name='market_closing[token]'][value=?]", Game::Market::CurrentSettings.call.token
        assert_select "textarea[name='market_closing[message_fr]']:not([disabled])"
        assert_select "button", "Close the market"
      end
    end

    test "a closed market shows the opening form and no closing section" do
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :en)

      assert_select "#market-opening"
      assert_select "#market-closing", false
    end

    test "a moderator reads the closing section of an open market disabled, with the reason" do
      open_market!(first_opened_at: Time.current)
      sign_in(accounts_players(:moderator))

      get back_office_market_path(locale: :en)

      assert_select "[data-market-closing-reason]", /administrator/
      assert_select "#market-closing fieldset[disabled][aria-describedby=market-closing-reason]"
      assert_select "#market-closing button[disabled]", "Close the market"
      assert_select "#market-closing button[type=submit]", false
    end

    test "a moderator reads the page with every control disabled and the reason shown" do
      sign_in(accounts_players(:moderator))

      get back_office_market_path(locale: :en)

      assert_response :success
      assert_select "[data-market-opening-reason]", /administrator/
      assert_select "fieldset[disabled][aria-describedby=market-opening-reason]", 2
      assert_select "textarea:not([disabled])", false
      assert_select "button[disabled]", "Open the market"
      assert_select "button[type=submit]", false
    end

    test "a player and a visitor see an unknown address" do
      sign_in(accounts_players(:player))
      get back_office_market_path(locale: :en)
      assert_unknown_address
    end

    test "the dashboard leads staff to the market" do
      sign_in(accounts_players(:moderator))

      get back_office_path(locale: :en)

      assert_select "a[href='/en/back-office/market'] .office-tile__title", "The market"
    end

    test "the market screen answers at the market's address once the market is closed after an opening" do
      close_market!(first_opened_at: Time.current)

      get market_path(locale: :en)

      assert_response :success
      assert_select "h1", "Market"
      assert_select "#market-suspended-banner", false
    end

    test "the market screen answers at the market's address once the market is open" do
      open_market!(first_opened_at: Time.current)

      get market_path(locale: :en)

      assert_response :success
      assert_select "h1", "Market"
    end

    def alerting_market!
      open_market!(first_opened_at: 10.days.ago, alert_destroyed_share_basis_points: 4_000)
      snapshot!(Time.current.utc.to_date - 1, created: 10_000, destroyed_total: 3_400)
    end

    test "an administrator preparing an alert gets the form prefilled, the changed fields marked and the first one focused, and nothing is written" do
      alerting_market!
      sign_in(accounts_players(:administrator))

      assert_no_difference -> { Game::Market::Settings.count } do
        get back_office_market_path(locale: :en, prepare: "destroyed_share")
      end

      assert_response :success
      assert_select "[data-market-settings-prepared]", /Nothing is saved until you save/
      assert_select "input[name='market_settings[stamp_rare]'][value='3000'][data-prepared][autofocus]"
      assert_select "input[name='market_settings[minimum_price_rare]'][value='8900'][data-prepared]:not([autofocus])"
      assert_select "[data-market-settings-prepared-field=stamp_rare]", /it was 2,000/
      assert_select "input[data-prepared]", 2
      assert_select "input[autofocus]", 1
      assert_select "input[name='market_settings[stamp_epic]'][value='5000']:not([data-prepared])"
      assert_select "input[name='market_settings[token]'][value=?]", Game::Market::CurrentSettings.call.token
    end

    test "the prefilled values save through the form with the announcement, and only then the version changes" do
      alerting_market!
      sign_in(accounts_players(:administrator))
      before = Game::Market::CurrentSettings.call
      form = BackOffice::MarketSettingsForm.from_settings(before).prepare(stamp_rare: 3_000, minimum_price_rare: 8_900)
      fields = Game::Market::SettingsRules::EDITABLE.index_with { form.value_for(it) }

      post back_office_market_settings_path(locale: :en), params: { market_settings: fields.merge(token: before.token,
        message_fr: "Le timbre Rare monte.", message_en: "The Rare stamp rises.") }

      assert_response :see_other
      current = Game::Market::CurrentSettings.call
      assert_equal [ 3_000, 8_900, before.id ], [ current.stamp_rare, current.minimum_price_rare, current.replaces_id ]
      assert_equal before.stamp_epic, current.stamp_epic
    end

    test "a moderator preparing an alert gets the plain form" do
      alerting_market!
      sign_in(accounts_players(:moderator))

      get back_office_market_path(locale: :en, prepare: "destroyed_share")

      assert_select "[data-market-settings-prepared]", false
      assert_select "input[data-prepared]", false
    end

    test "an alert that is quiet, unknown or not a name gets the plain form" do
      alerting_market!
      sign_in(accounts_players(:administrator))

      [ "top_share", "nothing", { stamp_rare: "9" } ].each do |prepare|
        get back_office_market_path(locale: :en, prepare:)

        assert_response :success
        assert_select "input[data-prepared]", false
      end
    end
  end
end
