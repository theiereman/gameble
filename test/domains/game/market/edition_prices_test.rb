require "test_helper"
require_relative "../../../support/market"

class Game::Market::EditionPricesTest < ActiveSupport::TestCase
  include MarketSettings

  setup do
    @priced = catalog_card_seasons(:common_card_one)
    @few = catalog_card_seasons(:rare_card_one)
    @none = catalog_card_seasons(:uncommon_card_one)
    open_market!(first_opened_at: 1.day.ago)
  end

  def prices(*cards) = Game::Market::EditionPrices.call(cards.map(&:id))

  test "five sales are priced, two are few sales, none is no sale" do
    Game::Market::EditionPrice.create!(card_season_id: @priced.id, average: 15_000, sales_used: 5)
    Game::Market::EditionPrice.create!(card_season_id: @few.id, average: 8_000, sales_used: 2)

    found = prices(@priced, @few, @none)

    assert found.fetch(@priced.id).priced?
    assert_equal 15_000, found.fetch(@priced.id).average
    assert found.fetch(@few.id).few_sales?
    assert_equal 2, found.fetch(@few.id).sales_used
    assert found.fetch(@none.id).no_sale?
  end

  test "a row with no sale used is no sale" do
    Game::Market::EditionPrice.create!(card_season_id: @none.id, average: nil, sales_used: 0)

    assert prices(@none).fetch(@none.id).no_sale?
  end

  test "nothing is answered before the first opening" do
    Game::Market::Settings.connection.execute("DELETE FROM game_market_settings")
    open_market!

    assert_equal({}, prices(@priced))
  end

  test "nothing is answered with no settings at all" do
    assert_equal({}, Game::Market::EditionPrices.call([ @priced.id ], state: Game::Market::MarketState.call(nil)))
  end

  test "one query reads every asked edition" do
    state = Game::Market::MarketState.call

    assert_queries_count(1) { Game::Market::EditionPrices.call([ @priced.id, @few.id, @none.id ], state:) }
  end
end
