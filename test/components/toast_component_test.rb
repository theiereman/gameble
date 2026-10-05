require "test_helper"

class ToastComponentTest < ViewComponent::TestCase
  test "a notice: its steady light, its line and a close button named in the locale" do
    I18n.with_locale(:fr) { render_inline(ToastComponent.new(message: "Proposition envoyée.")) }

    assert_selector ".toast.toast--notice[data-turbo-temporary][data-toast-target=toast]"
    assert_selector ".toast > .toast__light[aria-hidden=true]"
    assert_selector ".toast__message", text: "Proposition envoyée."
    assert_no_selector ".toast__title"
    assert_selector "button.toast__close[type=button][aria-label=Fermer][data-action='toast#close'] svg.pixel-icon[aria-hidden=true]"
  end

  test "an alert with a title" do
    I18n.with_locale(:en) { render_inline(ToastComponent.new(message: "Nothing moved.", title: "Not enough copies", tone: :alert)) }

    assert_selector ".toast.toast--alert"
    assert_selector ".toast__title", text: "Not enough copies"
    assert_selector ".toast__message", text: "Nothing moved."
    assert_selector "button.toast__close[aria-label=Close]"
  end

  test "an unknown tone is refused" do
    assert_raises(ArgumentError) { ToastComponent.new(message: "x", tone: :success) }
  end
end
