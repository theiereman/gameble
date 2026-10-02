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

  test "a button with an href and a method renders a one-button form with its params" do
    render_inline(ButtonComponent.new(href: "/auth/steam", method: :post, params: { origin: "/fr" }, turbo: false)) { "Enlist" }

    assert_selector "form.button-form[action='/auth/steam'][method=post][data-turbo=false]"
    assert_selector "form input[type=hidden][name=origin][value='/fr']", visible: :all
    assert_selector "form button.button.button--primary[type=submit]", text: "Enlist"
    assert_no_selector "a"
  end

  test "a DELETE form button carries the method override and stays a Turbo form" do
    render_inline(ButtonComponent.new(variant: :secondary, href: "/session", method: :delete)) { "Stand down" }

    assert_selector "form.button-form[action='/session'][method=post]"
    assert_no_selector "form[data-turbo]"
    assert_selector "form input[name=_method][value=delete]", visible: :all
    assert_selector "form button.button--secondary", text: "Stand down"
  end

  test "a form button needs an href" do
    assert_raises(ArgumentError) { ButtonComponent.new(method: :post) }
  end

  test "an unknown variant is refused" do
    assert_raises(ArgumentError) { ButtonComponent.new(variant: :tertiary) }
  end
end
