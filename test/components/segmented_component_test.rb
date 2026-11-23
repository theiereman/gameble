require "test_helper"

class SegmentedComponentTest < ViewComponent::TestCase
  def options
    [ { value: "order", label: "TO THE ORDER", amount: 900, accessible: "To the order, 900 PiCoins", disabled: true },
      { value: "auction", label: "AUCTION", describedby: "auction-note", checked: true, data: { choice: "auction" } },
      { value: "entrust", label: "ENTRUST", amount: 50 } ]
  end

  test "a named radio group of native radios sharing one name" do
    render_inline(SegmentedComponent.new(name: "lines[0][choice]", label: "Pyre, rare, season 1: your choice", options:, describedby: "no-order",
      class: "wanted-line__choice", data: { line: "pyre:1" }))

    assert_selector ".segmented.wanted-line__choice[role=radiogroup][aria-label='Pyre, rare, season 1: your choice'][aria-describedby=no-order][data-line='pyre:1']"
    assert_selector "label.segmented__option input[type=radio][name='lines[0][choice]']", count: 3
    assert_selector "input[value=order][disabled][aria-label='To the order, 900 PiCoins']"
    assert_selector "input[value=auction][checked][aria-describedby=auction-note][data-choice=auction]"
    assert_no_selector "input[value=entrust][checked], input[value=entrust][disabled], input[value=entrust][aria-label]"
    assert_selector ".segmented__option", text: "AUCTION"
    assert_selector ".segmented__amount .picoin-amount", count: 2
    assert_no_selector ".segmented--vertical-on-phone"
  end

  test "it stacks as rows on a phone when asked" do
    render_inline(SegmentedComponent.new(name: "size", label: "Size", options: [ { value: "s", label: "S" } ], vertical_on_phone: true))

    assert_selector ".segmented.segmented--vertical-on-phone"
    assert_no_selector "[aria-describedby]"
  end
end
