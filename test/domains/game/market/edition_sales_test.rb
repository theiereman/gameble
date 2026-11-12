require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_sales"

class Game::Market::EditionSalesTest < ActiveSupport::TestCase
  include MarketSettings
  include MarketSales

  setup do
    open_market!(first_opened_at: 60.days.ago)
    @edition = catalog_card_seasons(:rare_card_one)
    @settings = Game::Market::CurrentSettings.call
  end

  def chart = Game::Market::EditionSales.call(@edition.id)

  test "the chart holds the edition's sales within the average price window, oldest first, with the rarity's floor" do
    sold!(@edition, 2_000, sold_at: (@settings.average_window_days + 1).days.ago, average_after_sale: 2_000)
    sold!(@edition, 2_400, sold_at: 3.days.ago, average_after_sale: 2_400)
    sold!(@edition, 2_200, sold_at: 1.day.ago, average_after_sale: 2_300)
    sold!(catalog_card_seasons(:common_card_one), 9_999, sold_at: 1.hour.ago)

    result = chart

    assert_equal [ 2_400, 2_200 ], result.sales.map(&:final_price)
    assert_equal 2, result.count
    assert_equal :rare, result.rarity
    assert_equal @settings.minimum_price(:rare), result.floor
    assert_equal @settings.average_window_days, result.window_days
  end

  test "under the minimum sale count there is no average, from it the last stored average" do
    2.times { |ago| sold!(@edition, 2_000 + ago, sold_at: (ago + 1).days.ago, average_after_sale: 2_000) }
    assert_not chart.averaged?
    assert_nil chart.last_average

    sold!(@edition, 3_000, sold_at: 1.hour.ago, average_after_sale: 2_100)
    assert chart.averaged?
    assert_equal 2_100, chart.last_average
  end

  test "the window keeps at most the settings' sale count, the most recent" do
    (@settings.average_sale_count + 2).times { |ago| sold!(@edition, 1_500 + ago, sold_at: (ago + 1).hours.ago) }

    assert_equal @settings.average_sale_count, chart.count
    assert_equal 1_500, chart.last_sale.final_price
  end

  test "the fingerprint is the price row's sale count and refresh time, none without a sale" do
    assert_nil Game::Market::EditionSales.fingerprint(@edition.id)

    refreshed_at = Time.utc(2026, 11, 10, 9)
    Game::Market::EditionPrice.create!(card_season_id: @edition.id, average: 2_000, sales_used: 2, refreshed_at:)

    assert_equal Game::Market::EditionSales::Fingerprint.new(sales_used: 2, refreshed_at:), Game::Market::EditionSales.fingerprint(@edition.id)
  end
end
