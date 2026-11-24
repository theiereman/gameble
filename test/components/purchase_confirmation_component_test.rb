require "test_helper"

class PurchaseConfirmationComponentTest < ViewComponent::TestCase
  def confirmation(state, price: 500, available: 300, url: nil, refusal: nil)
    render_inline(PurchaseConfirmationComponent.new(title: "Buy?", title_id: "buy-title", state:, price:, available:, url:, refusal:, entrust: false))
  end

  test "a buyable purchase reads the balance after it" do
    confirmation(:buyable, price: 200, url: "/en/buy")

    assert_selector ".purchase-confirmation__fact", text: /Balance after\s+100/
    assert_selector "form[action='/en/buy']"
  end

  test "a closed purchase reads no balance after it, even with a price over the balance" do
    confirmation(:closed)

    assert_selector ".purchase-confirmation__fact", text: /Balance after\s+—/
    assert_no_selector ".purchase-confirmation__fact", text: /-200/
    assert_no_selector "form"
  end

  test "a purchase short of PiCoins reads no balance after it" do
    confirmation(:short)

    assert_selector ".purchase-confirmation__fact", text: /Balance after\s+—/
  end

  test "a capped purchase draws only the cancel button" do
    confirmation(:capped, refusal: "Limit reached.")

    assert_no_selector "form"
    assert_selector ".purchase-confirmation__refusal", text: "Limit reached."
  end
end
