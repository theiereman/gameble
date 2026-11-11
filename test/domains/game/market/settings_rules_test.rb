require "test_helper"
require_relative "../../../support/market"

class Game::Market::SettingsRulesTest < ActiveSupport::TestCase
  include MarketSettings

  setup do
    Game::Market::Settings.delete_all
    @current = open_market!
    @rules = Game::Market::SettingsRules.new(@current)
  end

  def candidate(**changes)
    Game::Market::SettingsRules::EDITABLE.index_with { @current.public_send(it) }.merge(changes)
  end

  def violations(**changes) = @rules.violations(candidate(**changes))

  def code_of(field, **changes) = violations(**changes)[field]&.code

  test "the version in force is within its own rules" do
    assert_empty violations
  end

  test "an amount, a minimum and the cap are accepted at exactly twice and exactly half the current value" do
    assert_nil code_of(:entrustment_rare, entrustment_rare: 10_000)
    assert_nil code_of(:entrustment_rare, entrustment_rare: 2_500)
    assert_nil code_of(:stamp_rare, stamp_rare: 4_000, minimum_price_rare: 15_600)
    assert_nil code_of(:daily_cap, daily_cap: 2_400_000)
    assert_nil code_of(:daily_cap, daily_cap: 600_000)
  end

  test "an amount beyond double or under half, rounded up, is refused with its limit" do
    assert_equal :more_than_double, code_of(:entrustment_rare, entrustment_rare: 10_001)
    assert_equal :less_than_half, code_of(:entrustment_rare, entrustment_rare: 2_499)
    assert_equal({ limit: 10_000 }, violations(entrustment_rare: 10_001)[:entrustment_rare].values)
    assert_equal :more_than_double, code_of(:daily_cap, daily_cap: 2_400_001)
  end

  test "half is rounded up for an odd value" do
    odd = open_market!(entrustment_common: 1_001)
    rules = Game::Market::SettingsRules.new(odd)
    candidate = Game::Market::SettingsRules::EDITABLE.index_with { odd.public_send(it) }

    assert_equal [ 501, 2_002 ], rules.amount_limits(:entrustment_common)
    assert_nil rules.violations(candidate.merge(entrustment_common: 501))[:entrustment_common]
    assert_equal :less_than_half, rules.violations(candidate.merge(entrustment_common: 500))[:entrustment_common].code
  end

  test "an amount at zero or under is out of range" do
    assert_equal :out_of_range, code_of(:stamp_common, stamp_common: 0)
    assert_equal :out_of_range, code_of(:stamp_common, stamp_common: -5)
  end

  test "a minimum under its no-loss floor is refused naming the floor" do
    violation = violations(minimum_price_rare: 7_700)[:minimum_price_rare]

    assert_equal :below_floor, violation.code
    assert_equal({ floor: 7_800 }, violation.values)
    assert_nil code_of(:minimum_price_rare, minimum_price_rare: 7_800)
  end

  test "the floor follows the candidate's own entrustment, stamp and commission" do
    assert_equal 7_800, @rules.floor(5_000, 2_000, 1_000)
    assert_equal 8_900, @rules.floor(5_000, 3_000, 1_000)
    assert_equal :below_floor, code_of(:minimum_price_rare, stamp_rare: 3_000)
    assert_nil code_of(:minimum_price_rare, stamp_rare: 3_000, minimum_price_rare: 8_900)
    assert_equal :below_floor, code_of(:minimum_price_rare, commission_basis_points: 2_500, minimum_price_rare: 7_800)
  end

  test "the floor is not computed when its inputs are unparsed" do
    assert_nil code_of(:minimum_price_rare, stamp_rare: "abc", minimum_price_rare: 3_900)
    assert_equal :not_a_number, code_of(:stamp_rare, stamp_rare: "abc")
    assert_nil code_of(:minimum_price_rare, commission_basis_points: nil, minimum_price_rare: 3_900)
  end

  test "the commission accepts 0 and 2500 basis points and refuses 2501 and a negative" do
    assert_nil code_of(:commission_basis_points, commission_basis_points: 0)
    assert_nil code_of(:commission_basis_points, commission_basis_points: 2_500)
    assert_equal :out_of_range, code_of(:commission_basis_points, commission_basis_points: 2_501)
    assert_equal :out_of_range, code_of(:commission_basis_points, commission_basis_points: -1)
  end

  {
    increment_basis_points: [ 100, 2_000 ], duration_short_hours: [ 1, 720 ], duration_long_hours: [ 1, 720 ], soft_close_seconds: [ 30, 900 ],
    average_sale_count: [ 3, 20 ], average_window_days: [ 7, 365 ], feed_threshold_multiple: [ 2, 100 ], unusual_maximum_multiple: [ 2, 20 ],
    alert_destroyed_share_basis_points: [ 0, 10_000 ], alert_picoins_per_player: [ 1, 1_000_000_000_000 ], alert_top_share_basis_points: [ 1, 10_000 ]
  }.each do |field, (low, high)|
    test "#{field} is accepted at #{low} and #{high} and refused beyond" do
      assert_nil code_of(field, field => low)
      assert_nil code_of(field, field => high)
      assert_equal :out_of_range, code_of(field, field => low - 1)
      assert_equal :out_of_range, code_of(field, field => high + 1)
    end
  end

  test "duration_medium_hours is accepted between its neighbours at the bounds and refused beyond them" do
    assert_nil code_of(:duration_medium_hours, duration_short_hours: 1, duration_medium_hours: 2)
    assert_nil code_of(:duration_medium_hours, duration_medium_hours: 719, duration_long_hours: 720)
    assert_equal :out_of_range, code_of(:duration_medium_hours, duration_medium_hours: 0)
    assert_equal :out_of_range, code_of(:duration_medium_hours, duration_medium_hours: 721)
  end

  test "the three durations grow strictly and the preselected one is among them" do
    assert_equal :durations_not_ascending, code_of(:duration_medium_hours, duration_short_hours: 24)
    assert_equal :durations_not_ascending, code_of(:duration_medium_hours, duration_long_hours: 24)
    assert_nil code_of(:duration_medium_hours, duration_short_hours: 23)
    assert_equal :preselected_not_a_duration, code_of(:preselected_duration_hours, preselected_duration_hours: 13)
    assert_nil code_of(:preselected_duration_hours, preselected_duration_hours: 72)
  end

  test "a required field that is nil or text is not a number and nothing else" do
    Game::Market::SettingsRules::REQUIRED.each do |field|
      [ nil, "abc" ].each do |value|
        found = violations(field => value)

        assert_equal :not_a_number, found[field]&.code, "#{field} with #{value.inspect}"
      end
    end
  end

  test "a decimal in an integer field is not a number" do
    assert_equal :not_a_number, code_of(:entrustment_rare, entrustment_rare: BigDecimal("12.5"))
  end

  test "the optional fields are valid blank and not a number as text" do
    Game::Market::SettingsRules::OPTIONAL.each do |field|
      assert_nil code_of(field, field => nil), field
      assert_equal :not_a_number, code_of(field, field => "abc"), field
    end
  end

  test "an income target is accepted from 0.001 to 365 days" do
    assert_nil code_of(:income_days_target_rare, income_days_target_rare: BigDecimal("0.001"))
    assert_nil code_of(:income_days_target_rare, income_days_target_rare: BigDecimal("365"))
    assert_equal :out_of_range, code_of(:income_days_target_rare, income_days_target_rare: BigDecimal("0"))
    assert_equal :out_of_range, code_of(:income_days_target_rare, income_days_target_rare: BigDecimal("365.001"))
    assert_equal :not_a_number, code_of(:income_days_target_rare, income_days_target_rare: 12)
  end

  test "every violation is reported at once" do
    found = violations(entrustment_rare: 99_999, soft_close_seconds: 1, average_sale_count: nil)

    %i[entrustment_rare soft_close_seconds average_sale_count].each { assert_includes found.keys, it }
  end

  test "only the editable columns are known" do
    assert_not_includes Game::Market::SettingsRules::EDITABLE, :open
    assert_not_includes Game::Market::SettingsRules::EDITABLE, :first_opened_at
    assert_not_includes Game::Market::SettingsRules::EDITABLE, :terms_confirmed_at
  end
end
