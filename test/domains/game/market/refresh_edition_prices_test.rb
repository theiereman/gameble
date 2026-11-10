require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_sales"

class Game::Market::RefreshEditionPricesTest < ActiveSupport::TestCase
  include MarketSales
  include MarketSettings

  setup do
    @card = catalog_card_seasons(:common_card_one)
    @other = catalog_card_seasons(:rare_card_one)
    @settings = open_market!(average_sale_count: 5, average_window_days: 90)
    @now = Time.current
  end

  def refresh = Game::Market::RefreshEditionPrices.new.call(now: @now).value!

  def stored(card = @card) = Game::Market::EditionPrice.find_by!(card_season_id: card.id)

  def store!(card, average:, sales_used:, refreshed_at: 5.days.ago)
    Game::Market::EditionPrice.create!(card_season_id: card.id, average:, sales_used:, refreshed_at:)
  end

  test "a sale that left the window moves the average and the sales used" do
    store!(@card, average: 20_000, sales_used: 3)
    sold!(@card, 10_000, sold_at: 100.days.ago)
    sold!(@card, 20_000, sold_at: 2.days.ago)
    sold!(@card, 30_000, sold_at: 3.days.ago)

    assert_equal 1, refresh

    assert_equal [ 25_000, 2 ], stored.values_at(:average, :sales_used)
  end

  test "a row that already matches the formula is left alone" do
    sold!(@card, 10_000, sold_at: 2.days.ago)
    before = store!(@card, average: 10_000, sales_used: 1)

    assert_equal 0, refresh

    assert_equal before.refreshed_at.to_i, stored.refreshed_at.to_i
  end

  test "a changed window setting moves the rows to it" do
    sold!(@card, 10_000, sold_at: 20.days.ago)
    store!(@card, average: 10_000, sales_used: 1)
    open_market!(average_sale_count: 5, average_window_days: 7)

    assert_equal 1, refresh

    assert_equal [ nil, 0 ], stored.values_at(:average, :sales_used)
  end

  test "a row with no sale used is not read and stays" do
    store!(@other, average: nil, sales_used: 0)

    assert_equal 0, refresh

    assert_equal [ nil, 0 ], stored(@other).values_at(:average, :sales_used)
  end

  test "each edition is refreshed on its own" do
    store!(@card, average: 99, sales_used: 1)
    store!(@other, average: 50_000, sales_used: 1)
    sold!(@card, 10_000, sold_at: 1.day.ago)
    sold!(@other, 50_000, sold_at: 1.day.ago)

    assert_equal 1, refresh

    assert_equal 10_000, stored.average
    assert_equal 50_000, stored(@other).average
  end

  test "it publishes nothing" do
    store!(@card, average: 99, sales_used: 1)
    sold!(@card, 10_000, sold_at: 1.day.ago)

    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      refresh
    end
  end
end
