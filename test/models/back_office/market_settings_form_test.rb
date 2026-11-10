require "test_helper"
require_relative "../../support/market"

module BackOffice
  class MarketSettingsFormTest < ActiveSupport::TestCase
    include MarketSettings

    setup do
      Game::Market::Settings.delete_all
      @settings = open_market!
    end

    def form_for(**typed)
      drawn = MarketSettingsForm.from_settings(@settings)
      MarketSettingsForm.from_params(Game::Market::SettingsRules::EDITABLE.index_with { drawn.value_for(it) }.merge(typed), settings: @settings)
    end

    def candidate(**typed) = form_for(**typed).candidate

    test "a form from a settings row reads the row's values" do
      form = MarketSettingsForm.from_settings(@settings)

      assert_equal @settings.token, form.token
      assert_equal 5_000, form.candidate[:entrustment_rare]
      assert_equal "5000", form.value_for(:entrustment_rare)
      assert_equal "10", form.value_for(:commission_basis_points)
      assert_equal "5", form.value_for(:increment_basis_points)
      assert_equal "", form.value_for(:income_days_target_rare)
      assert_empty form.violations
    end

    test "blank is nil" do
      assert_nil candidate(alert_picoins_per_player: "  ")[:alert_picoins_per_player]
      assert_nil candidate(daily_cap: nil)[:daily_cap]
    end

    test "an integer field reads digits and a sign, with whitespace and no-break spaces stripped" do
      assert_equal 1_200_000, candidate(daily_cap: "1 200 000")[:daily_cap]
      assert_equal 1_200_000, candidate(daily_cap: "1 200 000")[:daily_cap]
      assert_equal 1_200_000, candidate(daily_cap: "1 200 000")[:daily_cap]
      assert_equal(-5, candidate(daily_cap: "-5")[:daily_cap])
      assert_equal 7, candidate(soft_close_seconds: "007")[:soft_close_seconds]
    end

    test "text that is not a whole number stays the raw text" do
      assert_equal "abc", candidate(daily_cap: "abc")[:daily_cap]
      assert_equal "1 2 x", candidate(daily_cap: "1 2 x")[:daily_cap]
      assert_equal "12.5", candidate(soft_close_seconds: "12.5")[:soft_close_seconds]
      assert_equal "12,5", candidate(soft_close_seconds: "12,5")[:soft_close_seconds]
    end

    test "a percent is read with a comma or a dot and becomes basis points" do
      assert_equal 1_250, candidate(commission_basis_points: "12,5")[:commission_basis_points]
      assert_equal 1_250, candidate(commission_basis_points: "12.5")[:commission_basis_points]
      assert_equal 2_500, candidate(commission_basis_points: "25")[:commission_basis_points]
      assert_equal 2_501, candidate(commission_basis_points: "25.01")[:commission_basis_points]
      assert_equal(-100, candidate(commission_basis_points: "-1")[:commission_basis_points])
    end

    test "a percent is rounded to the nearest basis point" do
      assert_equal 1_235, candidate(commission_basis_points: "12.345")[:commission_basis_points]
      assert_equal 1_234, candidate(commission_basis_points: "12.344")[:commission_basis_points]
    end

    test "a percent that is not a number stays the raw text" do
      assert_equal "abc", candidate(commission_basis_points: "abc")[:commission_basis_points]
      assert_equal "1.2.3", candidate(commission_basis_points: "1.2.3")[:commission_basis_points]
    end

    test "a day target is a decimal rounded to three places" do
      assert_equal BigDecimal("12.5"), candidate(income_days_target_rare: "12,5")[:income_days_target_rare]
      assert_equal BigDecimal("12.5"), candidate(income_days_target_rare: "12.5")[:income_days_target_rare]
      assert_equal BigDecimal("0.123"), candidate(income_days_target_rare: "0.1234")[:income_days_target_rare]
      assert_equal "abc", candidate(income_days_target_rare: "abc")[:income_days_target_rare]
    end

    test "the typed text and the token of a refused form are kept" do
      form = MarketSettingsForm.from_params({ commission_basis_points: "12,5", daily_cap: "abc", message_fr: "Bonjour", message_en: "Hello" },
        settings: @settings, token: "submitted").check

      assert_equal "submitted", form.token
      assert_equal "12,5", form.value_for(:commission_basis_points)
      assert_equal "abc", form.value_for(:daily_cap)
      assert_equal "Bonjour", form.message_fr
      assert_equal "Hello", form.message_en
      assert_equal :not_a_number, form.violation(:daily_cap).code
    end

    test "violations are drawn only once the form is checked" do
      form = form_for(daily_cap: "abc")

      assert_empty form.violations
      assert_equal :not_a_number, form.check.violation(:daily_cap).code
    end

    test "a violation message names its bound in the field's own unit" do
      form = form_for(minimum_price_rare: "7700", commission_basis_points: "30").check

      assert_equal "Below the no-loss floor: at least 7,800.", form.violation_message(:minimum_price_rare)
      assert_match(/from 0 to 25/i, form.violation_message(:commission_basis_points))
    end

    test "a hint names the current value, the bounds and the moment" do
      hint = MarketSettingsForm.from_settings(@settings).hint(:stamp_rare)

      assert_includes hint, "2,000"
      assert_includes hint, "1,000"
      assert_includes hint, "4,000"
      assert_includes hint, "listing"
    end
  end
end
