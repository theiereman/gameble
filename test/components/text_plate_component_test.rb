require "test_helper"

class TextPlateComponentTest < ViewComponent::TestCase
  test "it renders its text on a plate, in a div by default" do
    render_inline(TextPlateComponent.new) { "Stand ready" }

    assert_selector "div.text-plate", text: "Stand ready"
  end

  test "it renders in the tag it is given" do
    render_inline(TextPlateComponent.new(tag: :p)) { "Stand ready" }

    assert_selector "p.text-plate", text: "Stand ready"
    assert_no_selector "div.text-plate"
  end
end
