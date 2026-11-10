require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_snapshots"

class Game::Market::EconomySeriesTest < ActiveSupport::TestCase
  include MarketSettings
  include MarketSnapshots

  setup do
    clear_snapshots
    @now = Time.utc(2026, 11, 10, 8)
    @last_day = Date.new(2026, 11, 9)
  end

  def series(settings = open_market!) = Game::Market::EconomySeries.call(now: @now, settings:)

  test "the window is 90 days ending on the last complete UTC day" do
    days = series.days

    assert_equal 90, days.size
    assert_equal @last_day, days.last
    assert_equal @last_day - 89, days.first
  end

  test "with no snapshot every point is null and there is no latest snapshot" do
    result = series

    assert_nil result.latest
    assert_equal [ nil ], result.destroyed_share.values.uniq
    assert_equal [ nil ], result.picoins_per_player.values.uniq
    assert_equal [ nil ], result.top_share.values.uniq
    assert(result.days_of_income.values.all? { |indicator| indicator.values.uniq == [ nil ] })
  end

  test "destroyed against created is the ratio of the sums over 30 days, in basis points" do
    snapshot!(@last_day - 40, created: 100_000, destroyed_total: 0)
    snapshot!(@last_day - 2, created: 1_000, destroyed_total: 100)
    snapshot!(@last_day - 1, created: 3_000, destroyed_total: 1_700)
    snapshot!(@last_day, created: 6_000, destroyed_total: 2_200)

    values = series.destroyed_share.values

    assert_equal 1_000, values[-3]
    assert_equal 4_500, values[-2]
    assert_equal 4_000, values[-1]
    assert_nil values[-4]
  end

  test "nothing created in the window leaves the ratio null" do
    snapshot!(@last_day, created: 0, destroyed_total: 0)

    assert_nil series.destroyed_share.last
  end

  test "a day with no snapshot is null for the ratio even when its window has some" do
    snapshot!(@last_day - 1, created: 1_000, destroyed_total: 400)

    values = series.destroyed_share.values

    assert_equal 4_000, values[-2]
    assert_nil values[-1]
  end

  test "players and top share come from the snapshot as they are" do
    snapshot!(@last_day, picoins_per_active_player: 12_000, top_share_basis_points: 3_300)

    result = series

    assert_equal 12_000, result.picoins_per_player.last
    assert_equal 3_300, result.top_share.last
  end

  test "days of income divides a rarity's price by the median earnings, null when either is missing" do
    snapshot!(@last_day, average_price_rare: 12_000, average_price_epic: 9_000, median_daily_earnings: 8_000)
    snapshot!(@last_day - 1, average_price_rare: 12_000, median_daily_earnings: nil)

    income = series.days_of_income

    assert_in_delta 1.5, income[:rare].last
    assert_in_delta 1.125, income[:epic].last
    assert_nil income[:common].last
    assert_nil income[:rare].values[-2]
  end

  test "thresholds and targets are the current version's flat series, nil where blank" do
    settings = open_market!(alert_destroyed_share_basis_points: 4_000, alert_picoins_per_player: nil, income_days_target_epic: BigDecimal("1.5"))

    result = series(settings)

    assert_equal [ 4_000 ] * 90, result.destroyed_share.threshold
    assert_nil result.picoins_per_player.threshold
    assert_nil result.picoins_per_player.last_threshold
    assert_equal [ 1.5 ] * 90, result.days_of_income[:epic].threshold
    assert_nil result.days_of_income[:rare].threshold
  end

  test "a changed threshold does not redraw history" do
    snapshot!(@last_day - 1, created: 1_000, destroyed_total: 300)
    first = series(open_market!(alert_destroyed_share_basis_points: 4_000))
    second = series(open_market!(alert_destroyed_share_basis_points: 2_000))

    assert_equal first.destroyed_share.values, second.destroyed_share.values
    assert_equal [ 4_000, 2_000 ], [ first.destroyed_share.last_threshold, second.destroyed_share.last_threshold ]
  end

  test "the latest snapshot is the most recent one inside the window" do
    snapshot!(@last_day - 3, created: 1)
    latest = snapshot!(@last_day - 2, created: 2)
    snapshot!(@last_day - 100, created: 3)

    assert_equal latest, series.latest
  end

  test "a snapshot of today or later is outside the window" do
    snapshot!(@now.to_date, created: 5)

    assert_nil series.latest
  end

  test "no settings leaves every threshold nil" do
    result = Game::Market::EconomySeries.call(now: @now, settings: nil)

    assert_nil result.destroyed_share.threshold
    assert_nil result.top_share.threshold
    assert(result.days_of_income.values.all? { |indicator| indicator.threshold.nil? })
  end
end
