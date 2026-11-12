require "test_helper"
require_relative "../../../support/market_snapshots"

class Game::Market::EconomySeriesReactorTest < ActiveSupport::TestCase
  include MarketSnapshots

  setup do
    clear_snapshots
    @now = Time.utc(2026, 11, 10, 8)
    @last_day = Date.new(2026, 11, 9)
  end

  def reactor = Game::Market::EconomySeries.reactor(now: @now)

  test "the Reactor covers the last 30 complete UTC days" do
    days = reactor.days

    assert_equal 30, days.size
    assert_equal @last_day, days.last
    assert_equal @last_day - 29, days.first
  end

  test "each day reads minted, destroyed, its balance and the circulation from the snapshot" do
    snapshot!(@last_day, created: 12_000, destroyed_total: 5_000, forfeited: 1_000, circulation: 400_000)
    snapshot!(@last_day - 1, created: 3_000, destroyed_total: 4_500, circulation: 393_000)

    result = reactor

    assert_equal [ 3_000, 12_000 ], result.minted.last(2)
    assert_equal [ 4_500, 5_000 ], result.destroyed.last(2)
    assert_equal [ -1_500, 7_000 ], result.balance.last(2)
    assert_equal [ 393_000, 400_000 ], result.circulation.last(2)
  end

  test "a day without a snapshot is null everywhere, never 0, and the sums leave it out" do
    snapshot!(@last_day - 2, created: 10_000, destroyed_total: 6_000, circulation: 100_000)
    snapshot!(@last_day, created: 6_000, destroyed_total: 1_000, circulation: 109_000)

    result = reactor

    assert_nil result.minted[-2]
    assert_nil result.destroyed[-2]
    assert_nil result.balance[-2]
    assert_nil result.circulation[-2]
    assert_equal 16_000, result.minted_total
    assert_equal 7_000, result.destroyed_total
    assert_equal 4_375, result.destroyed_share_basis_points
    assert_equal 109_000, result.last_circulation
  end

  test "the last circulation is the newest known one" do
    snapshot!(@last_day - 3, circulation: 50_000)

    assert_equal 50_000, reactor.last_circulation
  end

  test "with no snapshot in the window every summary is null" do
    snapshot!(@last_day - 30, created: 9_000, destroyed_total: 9_000, circulation: 9_000)

    result = reactor

    assert result.empty?
    assert_equal [ nil ], result.minted.uniq
    assert_nil result.last_circulation
    assert_nil result.minted_total
    assert_nil result.destroyed_total
    assert_nil result.destroyed_share_basis_points
  end

  test "nothing minted leaves the ratio null" do
    snapshot!(@last_day, created: 0, destroyed_total: 400, circulation: 1_000)

    result = reactor

    assert_equal 0, result.minted_total
    assert_nil result.destroyed_share_basis_points
  end
end
