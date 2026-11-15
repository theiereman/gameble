require "test_helper"

class SortComponentTest < ViewComponent::TestCase
  test "one button names the current order and opens a menu of every order" do
    render_inline(SortComponent.new(prefix: "Sort:", label: "Sort the listings",
      options: [ { label: "Ending soon", href: "/ending" }, { label: "Newest", href: "/newest", current: true } ]))

    assert_selector "details.sort summary.sort__button", text: "Sort: Newest"
    assert_selector "nav.sort__menu[aria-label='Sort the listings'] a.sort__option", count: 2
    assert_selector "a.sort__option[aria-current=true][href='/newest']", text: "Newest", visible: :all
  end

  test "without a current option the first one is named" do
    render_inline(SortComponent.new(prefix: "Sort:", label: "Order", options: [ { label: "Ending soon", href: "/ending" } ]))

    assert_selector ".sort__current", text: "Ending soon"
  end
end
