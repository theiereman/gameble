require "test_helper"

class AveragePriceComponentTest < ViewComponent::TestCase
  def price(average, sales_used) = Game::Market::EditionPrices::Price.new(average:, sales_used:)

  test "a priced edition draws its amount alone" do
    render_inline AveragePriceComponent.new(price: price(15_000, 5))

    assert_selector ".average-price .picoin-amount[aria-label='15,000 PiCoins']"
    assert_no_selector ".average-price__few"
    assert_no_selector ".average-price--none"
  end

  test "an edition under the minimum draws its amount with few sales" do
    render_inline AveragePriceComponent.new(price: price(8_000, 2))

    assert_selector ".average-price .picoin-amount[aria-label='8,000 PiCoins']"
    assert_selector ".average-price__few", text: "few sales"
  end

  test "an edition with no sale says so and draws no amount" do
    render_inline AveragePriceComponent.new(price: price(nil, 0))

    assert_selector ".average-price.average-price--none", text: "No sale"
    assert_no_selector ".picoin-amount"
  end

  test "the amount can be compact and the words are French in French" do
    I18n.with_locale(:fr) do
      render_inline AveragePriceComponent.new(price: price(31_500, 2), compact: true)

      assert_selector ".picoin-amount__figure", text: "31,5k"
      assert_selector ".average-price__few", text: "peu de ventes"
    end
  end

  test "an absent price draws nothing" do
    render_inline AveragePriceComponent.new(price: nil)

    assert_no_selector ".average-price"
  end
end
