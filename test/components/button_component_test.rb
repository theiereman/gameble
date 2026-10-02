require "test_helper"

class ButtonComponentTest < ViewComponent::TestCase
  test "a primary button without href renders a button" do
    render_inline(ButtonComponent.new(variant: :primary)) { "Report for duty" }

    assert_selector "button.button.button--primary[type=button]", text: "Report for duty"
    assert_no_selector "a"
  end

  test "a secondary button with href renders a link" do
    render_inline(ButtonComponent.new(variant: :secondary, href: "/en")) { "Linger" }

    assert_selector "a.button.button--secondary[href='/en']", text: "Linger"
    assert_no_selector "button"
  end

  test "a button takes the submit type" do
    render_inline(ButtonComponent.new(type: :submit)) { "Send" }

    assert_selector "button.button--primary[type=submit]"
  end

  test "an unknown variant is refused" do
    assert_raises(ArgumentError) { ButtonComponent.new(variant: :tertiary) }
  end
end
