require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_snapshots"

class Game::Market::EconomySeriesThresholdsTest < ActiveSupport::TestCase
  include MarketSettings
  include MarketSnapshots

  setup do
    clear_snapshots
    @settings = open_market!(alert_destroyed_share_basis_points: 4_000, income_days_target_epic: BigDecimal("1.5"))
    @now = Time.utc(2026, 11, 10, 8)
    3.times do |ago|
      snapshot!(Date.new(2026, 11, 9) - ago, created: 10_000, destroyed_total: 5_000 + ago * 100, circulation: 400_000,
        median_daily_earnings: 10_000, average_price_epic: 14_000)
    end
  end

  teardown { clear_snapshots }

  test "a changed threshold moves the threshold line and leaves every drawn value as it was" do
    before = Game::Market::EconomySeries.call(now: @now, settings: @settings)
    changed = @settings.successor(author: accounts_players(:administrator), alert_destroyed_share_basis_points: 6_000,
      income_days_target_epic: BigDecimal("2"))
    after = Game::Market::EconomySeries.call(now: @now, settings: changed)

    assert_equal before.destroyed_share.values, after.destroyed_share.values
    assert_equal before.days_of_income[:epic].values, after.days_of_income[:epic].values
    assert_equal [ 4_000 ], before.destroyed_share.threshold.uniq
    assert_equal [ 6_000 ], after.destroyed_share.threshold.uniq
    assert_equal [ 2.0 ], after.days_of_income[:epic].threshold.uniq
    assert_equal 1.4, after.days_of_income[:epic].last
  end
end
