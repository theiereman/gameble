require "test_helper"

class AveragePriceHelperTest < ActionView::TestCase
  include PicoinsHelper

  def price(average, sales_used) = Game::Market::EditionPrices::Price.new(average:, sales_used:)

  test "the sale count under a price, none for no sale or no price" do
    assert_equal "Based on 5 sales", average_price_basis(price(15_000, 5))
    assert_equal "Based on 1 sale", average_price_basis(price(9_000, 1))
    assert_nil average_price_basis(price(nil, 0))
    assert_nil average_price_basis(nil)
  end

  test "the words that end a card's accessible name" do
    assert_equal "average price 15,000 PiCoins", average_price_words(price(15_000, 5))
    assert_equal "average price 8,000 PiCoins, few sales", average_price_words(price(8_000, 2))
    assert_equal "no sale", average_price_words(price(nil, 0))
    assert_nil average_price_words(nil)
  end

  test "in French" do
    I18n.with_locale(:fr) do
      assert_equal "Fondé sur 5 ventes", average_price_basis(price(15_000, 5))
      assert_equal "sans vente", average_price_words(price(nil, 0))
    end
  end
end
