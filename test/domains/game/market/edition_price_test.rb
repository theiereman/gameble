require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_sales"

class Game::Market::EditionPriceTest < ActiveSupport::TestCase
  include MarketSales
  include MarketSettings

  setup do
    @card = catalog_card_seasons(:common_card_one)
    @other = catalog_card_seasons(:rare_card_one)
    @settings = open_market!(average_sale_count: 5, average_window_days: 90)
    @now = Time.current
  end

  def average_of(prices) = Game::Market::EditionPrice.average_of(prices)

  def window(settings: @settings, card: @card) = Game::Market::EditionPrice.sales_in_window(card.id, settings:, now: @now)

  test "the minimum sales equal the lower bound of the sale count setting" do
    assert_equal Game::Market::SettingsRules::RANGES[:average_sale_count].min, Game::Market::EditionPrice::MINIMUM_SALES
  end

  test "no price gives no average" do
    assert_nil average_of([])
  end

  test "one and two prices drop nothing" do
    assert_equal 10_000, average_of([ 10_000 ])
    assert_equal 15_000, average_of([ 10_000, 20_000 ])
  end

  test "three prices drop the highest and the lowest" do
    assert_equal 20_000, average_of([ 30_000, 10_000, 20_000 ])
  end

  test "five prices drop the extremes and floor the mean" do
    assert_equal 15_000, average_of([ 10_000, 12_000, 15_000, 18_000, 40_000 ])
    assert_equal 15_000, average_of([ 10_000, 15_000, 15_000, 15_001, 40_000 ])
  end

  test "six prices drop one at each end" do
    assert_equal 25, average_of([ 1, 10, 20, 30, 40, 100 ])
  end

  test "the window reads the newest sales up to the count setting" do
    6.times { |index| sold!(@card, 10_000 + index, sold_at: (index + 1).days.ago) }

    assert_equal [ 10_000, 10_001, 10_002, 10_003, 10_004 ], window
  end

  test "a sale older than the window days is ignored" do
    sold!(@card, 10_000, sold_at: @now - 90.days - 1.second)
    sold!(@card, 20_000, sold_at: @now - 90.days + 1.second)

    assert_equal [ 20_000 ], window
  end

  test "a sale exactly at the window start is ignored" do
    sold!(@card, 10_000, sold_at: @now - 90.days)

    assert_empty window
  end

  test "equal sale times are read newest listing first" do
    at = 1.day.ago
    first = sold!(@card, 10_000, sold_at: at)
    second = sold!(@card, 20_000, sold_at: at)
    narrow = open_market!(average_sale_count: 3)

    assert_operator second.id, :>, first.id
    assert_equal [ 20_000, 10_000 ], window(settings: narrow)
  end

  test "another edition's sales and unsold listings are ignored" do
    sold!(@other, 99_000, sold_at: 1.day.ago)
    sold!(@card, 10_000, sold_at: 1.day.ago)
    Game::Market::Listing.create!(seller: accounts_players(:player), card_season_id: @card.id, settings_id: @settings.id, starting_price: 1_300, current_price: 1_300,
      duration_hours: 24, ends_at: 1.hour.from_now)

    assert_equal [ 10_000 ], window
  end

  test "a changed settings version changes the count and the window" do
    3.times { |index| sold!(@card, 10_000 + index, sold_at: (10 * (index + 1)).days.ago) }
    changed = open_market!(average_sale_count: 3, average_window_days: 15)

    assert_equal [ 10_000 ], window(settings: changed)
    assert_equal 3, window.size
  end

  test "the row is created once and locked" do
    first = Game::Market::EditionPrice.lock_row(@card.id)
    second = Game::Market::EditionPrice.lock_row(@card.id)

    assert_equal first.id, second.id
    assert_equal [ nil, 0 ], [ first.average, first.sales_used ]
  end

  test "an average with no sale used is refused by the table" do
    row = Game::Market::EditionPrice.lock_row(@card.id)

    assert_raises(ActiveRecord::StatementInvalid) { row.update_columns(average: 5) }
  end
end
