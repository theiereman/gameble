require "test_helper"

class PicoinAmountComponentTest < ViewComponent::TestCase
  FORMS = JSON.parse(file_fixture("picoin_forms.json").read)

  test "the visible figure of every fixture row reads as the fixture says" do
    FORMS.each do |row|
      I18n.with_locale(row["locale"]) do
        render_inline PicoinAmountComponent.new(amount: row["amount"], compact: row["compact"])

        assert_selector ".picoin-amount__figure", exact_text: row["text"]
      end
    end
  end

  test "the accessible name is the exact amount, whatever the visible form" do
    render_inline PicoinAmountComponent.new(amount: 31_500, compact: true)
    assert_selector ".picoin-amount[role=img][aria-label='31,500 PiCoins']"
    assert_selector ".picoin-amount__figure", exact_text: "31.5k"

    I18n.with_locale(:fr) do
      render_inline PicoinAmountComponent.new(amount: 31_500, compact: true)
      assert_selector ".picoin-amount[aria-label='31 500 PiCoins']"
      assert_selector ".picoin-amount__figure", exact_text: "31,5k"
    end
  end

  test "the mark is hidden from assistive technology" do
    render_inline PicoinAmountComponent.new(amount: 5_000)

    assert_selector ".picoin-amount svg[aria-hidden=true]", count: 1
    assert_no_selector ".picoin-amount--large"
    assert_no_selector "[style]"
  end

  test "the large size swaps the mark and adds the modifier" do
    small = render_inline(PicoinAmountComponent.new(amount: 5_000)).css("svg").first["viewBox"]
    render_inline PicoinAmountComponent.new(amount: 5_000, size: :large)

    assert_selector ".picoin-amount.picoin-amount--large"
    assert_not_equal small, page.find("svg")["viewBox"]
  end

  test "an unknown size is refused" do
    assert_raises(ArgumentError) { PicoinAmountComponent.new(amount: 1, size: :huge) }
  end

  test "an amount that is not a whole number is never drawn" do
    assert_raises(ArgumentError) { render_inline PicoinAmountComponent.new(amount: 1.5) }
  end
end
