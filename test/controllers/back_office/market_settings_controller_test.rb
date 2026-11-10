require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/market"
require_relative "../../support/singleton_stub"
require_relative "../../support/steam_sign_in"

module BackOffice
  class MarketSettingsControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include MarketSettings
    include SingletonStub
    include SteamSignIn

    setup do
      Game::Market::Settings.delete_all
      @current = open_market!(first_opened_at: 2.days.ago)
    end

    def typed_values(settings = Game::Market::CurrentSettings.call)
      drawn = MarketSettingsForm.from_settings(settings)
      Game::Market::SettingsRules::EDITABLE.index_with { drawn.value_for(it) }
    end

    def settings_params(token: @current.token, fr: "Les réglages changent", en: "The settings change", **typed)
      { market_settings: typed_values.merge(typed).merge(token:, message_fr: fr, message_en: en) }
    end

    def save(**)
      post back_office_market_settings_path(locale: :en), params: settings_params(**)
    end

    def nothing_is_written(&)
      assert_no_difference([ -> { Game::Market::Settings.count }, -> { Accounts::Announcement.count } ], &)
    end

    def refusal_lines = css_select("#market-settings ul[role=alert] li").map(&:text)

    test "an administrator saves a valid change and is redirected with a notice" do
      sign_in(accounts_players(:administrator))

      save(stamp_rare: "2500", minimum_price_rare: "8400")

      assert_redirected_to back_office_market_path(locale: :en)
      assert_equal 2_500, Game::Market::CurrentSettings.call.stamp_rare
      assert_equal [ "The settings change" ], Accounts::Announcement.where(shown: true).pluck(:message_en)
    end

    test "with the market open the form is present, a valid save succeeds and the opening section is absent" do
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :en)

      assert_select "#market-settings form[action='/en/back-office/market/settings']"
      assert_select "#market-opening", false
      save(daily_cap: "1300000")
      assert_redirected_to back_office_market_path(locale: :en)
      assert Game::Market::CurrentSettings.call.open
    end

    test "a field refused beside itself with 422, the typed text and the submitted token kept" do
      sign_in(accounts_players(:administrator))

      nothing_is_written { save(minimum_price_rare: "7700", commission_basis_points: "12,5", soft_close_seconds: "abc") }

      assert_response :unprocessable_content
      assert_equal [ "Some settings were refused. Check the marked fields." ], refusal_lines
      assert_select "#market-settings-minimum-price-rare[aria-invalid=true][value='7700']"
      assert_select "#market-settings-minimum-price-rare-error[role=alert]", /7,800/
      assert_select "input[name='market_settings[commission_basis_points]'][value='12,5']"
      assert_select "#market-settings-soft-close-seconds-error[role=alert]", /Enter a number/
      assert_select "input[name='market_settings[soft_close_seconds]'][value=abc]"
      assert_select "input[type=hidden][name='market_settings[token]'][value='#{@current.token}']"
    end

    test "a stale form shows the stale line with the new token, the typed text and the new amounts" do
      sign_in(accounts_players(:administrator))
      older_token = @current.token
      newer = open_market!(stamp_rare: 3_000)

      nothing_is_written { save(token: older_token, stamp_rare: "2100", fr: "Texte FR", en: "Text EN") }

      assert_response :unprocessable_content
      assert_equal [ "Another administrator has just changed the settings." ], refusal_lines
      assert_select "input[type=hidden][name='market_settings[token]'][value='#{newer.token}']"
      assert_select "input[name='market_settings[stamp_rare]'][value='2100']"
      assert_select "#market-settings-stamp-rare-hint", /Currently 3,000/
      assert_select "textarea[name='market_settings[message_fr]']", "Texte FR"
      assert_select "textarea[name='market_settings[message_en]']", "Text EN"
    end

    test "a refused announcement says the settings were not changed and keeps both texts" do
      sign_in(accounts_players(:administrator))

      nothing_is_written { save(fr: "", en: "Typed English") }

      assert_response :unprocessable_content
      assert_equal [ "Each announcement needs text in both languages, at most 280 characters. The settings were not changed." ], refusal_lines
      assert_no_match(/not opened/, response.body)
      assert_select "textarea[name='market_settings[message_en]']", "Typed English"
    end

    test "the typed announcements survive an invalid_settings refusal" do
      sign_in(accounts_players(:administrator))

      save(soft_close_seconds: "1", fr: "Texte FR", en: "Text EN")

      assert_select "textarea[name='market_settings[message_fr]']", "Texte FR"
      assert_select "textarea[name='market_settings[message_en]']", "Text EN"
    end

    test "a busy bank, a missing sign-in and a refused role each show their line with 422" do
      sign_in(accounts_players(:administrator))
      busy = Object.new.tap { |fake| fake.define_singleton_method(:call) { |**| Dry::Monads::Result::Failure.new(:market_busy) } }

      stub_singleton(Game::Market::ChangeSettings, :new, -> { busy }) { save }

      assert_response :unprocessable_content
      assert_equal [ Game::Market::ChangeSettings.failure_message(:market_busy) ], refusal_lines

      [ :administrator_required, :player_required ].each do |code|
        refused = Object.new.tap { |fake| fake.define_singleton_method(:call) { |**| Dry::Monads::Result::Failure.new(code) } }
        stub_singleton(Game::Market::ChangeSettings, :new, -> { refused }) { save }

        assert_response :unprocessable_content
        assert_equal [ Game::Market::ChangeSettings.failure_message(code) ], refusal_lines
      end
    end

    test "a moderator is refused by the policy and nothing is written" do
      sign_in(accounts_players(:moderator))

      nothing_is_written { save(daily_cap: "1300000") }

      assert_equal @current, Game::Market::CurrentSettings.call
    end

    test "a moderator reads every value with every control disabled and the reason" do
      sign_in(accounts_players(:moderator))

      get back_office_market_path(locale: :en)

      assert_response :success
      assert_select "#market-settings-reason"
      assert_select "#market-settings input[name^='market_settings[']:not([type=hidden]):not([disabled])", false
      assert_select "#market-settings textarea:not([disabled])", false
      assert_select "#market-settings button:not([disabled])", false
      assert_select "input[name='market_settings[stamp_rare]'][value='2000']"
    end

    test "the page is accessible by headers and announces its refusals" do
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :en)

      assert_select "#market-settings-stamp-rare[aria-labelledby='market-settings-row-stamp market-settings-col-rare']"
      assert_select "#market-settings-stamp-rare[aria-describedby~='market-settings-stamp-rare-hint']"
      assert_select "#market-settings-daily-cap" do
        assert_select "[aria-describedby~='market-settings-daily-cap-hint']"
      end
      assert_select "label[for=market-settings-daily-cap]"
      assert_select "[style]", false
    end

    test "with the market closed the two sections share no id and each posts its own fields" do
      close_market!(first_opened_at: 2.days.ago)
      sign_in(accounts_players(:administrator))

      get back_office_market_path(locale: :en)

      ids = css_select("[id]").map { it["id"] }
      assert_equal ids.uniq.size, ids.size
      assert_select "#market-settings textarea[name='market_settings[message_fr]']"
      assert_select "#market-opening textarea[name=message_fr]"
      assert_select "#market-settings form textarea[name=message_fr]", false
      assert_select "#market-opening form input[name^='market_settings']", false
      assert_select "#market-settings-announcement-fr"
      assert_select "#market-announcement-fr"
    end

    test "with no version the page draws the hint and no form, for an administrator and a moderator" do
      Game::Market::Settings.delete_all

      [ :administrator, :moderator ].each do |role|
        sign_in(accounts_players(role))

        get back_office_market_path(locale: :en)

        assert_response :success
        assert_select "#market-settings [data-market-settings-not-yet-open]"
        assert_select "#market-settings form", false
        assert_select "#market-settings input", false
        assert_select "form[action='/en/back-office/market/opening']"
      end
    end

    test "a forced post with no version re-renders the hint with 422" do
      Game::Market::Settings.delete_all
      sign_in(accounts_players(:administrator))

      post back_office_market_settings_path(locale: :en), params: { market_settings: { token: "x", message_fr: "a", message_en: "b" } }

      assert_response :unprocessable_content
      assert_select "#market-settings [data-market-settings-not-yet-open]"
      assert_select "#market-settings form", false
      assert_select "form[action='/en/back-office/market/opening']"
    end

    test "a post with no settings at all is a stale form, not an error" do
      sign_in(accounts_players(:administrator))

      post back_office_market_settings_path(locale: :en)

      assert_response :unprocessable_content
    end

    test "a failed opening still draws the settings form" do
      close_market!(first_opened_at: 2.days.ago)
      sign_in(accounts_players(:administrator))

      post back_office_market_opening_path(locale: :en), params: { terms_confirmed: "0", odds_confirmed: "0", message_fr: "a", message_en: "b" }

      assert_response :unprocessable_content
      assert_select "#market-settings form"
    end
  end
end
