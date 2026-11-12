require "test_helper"
require_relative "../../../support/market_snapshots"

class Game::Market::EconomySeriesRarityPricesTest < ActiveSupport::TestCase
  include MarketSnapshots

  setup do
    clear_snapshots
    @last_day = Date.new(2026, 11, 9)
  end

  teardown { clear_snapshots }

  def prices = Game::Market::EconomySeries.rarity_prices(through: @last_day)

  def priced!(day, epic:, median: 10_000)
    snapshot!(day, average_price_epic: epic, median_daily_earnings: median)
  end

  test "the rarity prices cover 90 days ending on the given day, one series per rarity" do
    result = prices

    assert_equal 90, result.days.size
    assert_equal @last_day, result.days.last
    assert_equal %i[common uncommon rare epic legendary], result.rarities
    assert result.empty?
  end

  test "each day's price is the rarity's average price in days of median income, missing without a price or an income" do
    priced!(@last_day - 2, epic: 15_000)
    snapshot!(@last_day - 1, average_price_epic: 16_000, median_daily_earnings: nil)
    priced!(@last_day, epic: 16_000)

    assert_equal [ 1.5, nil, 1.6 ], prices.days_of_income[:epic].last(3)
    assert_equal [ nil, nil, nil ], prices.days_of_income[:common].last(3)
    assert_equal 1.6, prices.last_days_of_income(:epic)
  end

  test "the index is 100 on the rarity's first day with a price, and its change runs from first to last price" do
    priced!(@last_day - 89, epic: 10_000)
    priced!(@last_day - 40, epic: 12_000)
    priced!(@last_day, epic: 14_300)

    result = prices

    assert_equal 100.0, result.index[:epic].first
    assert_equal 120.0, result.index[:epic][49]
    assert_equal 143.0, result.last_index(:epic)
    assert_equal 4_300, result.change_basis_points(:epic)
    assert_nil result.change_basis_points(:common)
    assert_equal :epic, result.highest_index_rarity
  end

  test "a snapshot outside the window counts neither in the series nor in the index base" do
    priced!(@last_day - 90, epic: 5_000)
    priced!(@last_day, epic: 14_000)

    assert_equal 100.0, prices.last_index(:epic)
    assert_nil prices.change_basis_points(:epic)
  end
end
