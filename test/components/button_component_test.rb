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

  test "a link with turbo off is a full-page load" do
    render_inline(ButtonComponent.new(variant: :secondary, href: "/back-office/jobs", turbo: false)) { "Jobs" }

    assert_selector "a.button.button--secondary[href='/back-office/jobs'][data-turbo=false]", text: "Jobs"
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

  test "a form button with confirm asks Turbo to confirm before sending" do
    render_inline(ButtonComponent.new(href: "/seasons/publish", method: :post, confirm: "Sure?")) { "Publish" }

    assert_selector "form.button-form[action='/seasons/publish'][data-turbo-confirm='Sure?']"
    assert_no_selector "form[data-turbo]"
    assert_selector "form button.button--primary", text: "Publish"
  end

  test "confirm and turbo off combine on the form" do
    render_inline(ButtonComponent.new(href: "/x", method: :post, confirm: "Sure?", turbo: false)) { "Go" }

    assert_selector "form[data-turbo-confirm='Sure?'][data-turbo=false]"
  end

  test "only a form button can ask for confirmation" do
    assert_raises(ArgumentError) { ButtonComponent.new(href: "/en", confirm: "Sure?") }
  end

  test "a form button needs an href" do
    assert_raises(ArgumentError) { ButtonComponent.new(method: :post) }
  end

  test "an unknown variant is refused" do
    assert_raises(ArgumentError) { ButtonComponent.new(variant: :tertiary) }
  end

  test "the danger and link variants" do
    render_inline(ButtonComponent.new(variant: :danger)) { "Delete" }
    assert_selector "button.button.button--danger", text: "Delete"

    render_inline(ButtonComponent.new(variant: :link, href: "/en/feed")) { "See all" }
    assert_selector "a.button.button--link[href='/en/feed']", text: "See all"
  end

  test "the default stays primary" do
    render_inline(ButtonComponent.new) { "Open" }

    assert_selector "button.button--primary"
  end

  test "a small button" do
    render_inline(ButtonComponent.new(variant: :secondary, size: :small, href: "/en")) { "Back" }

    assert_selector "a.button.button--secondary.button--small[href='/en']"
  end

  test "an unknown size is refused" do
    assert_raises(ArgumentError) { ButtonComponent.new(size: :huge) }
  end

  test "an icon comes before the label, hidden from assistive technology" do
    render_inline(ButtonComponent.new(variant: :secondary, href: "/en", icon: "arrow-left")) { "Bridge" }

    assert_selector "a.button > svg.pixel-icon.button__icon[aria-hidden=true][focusable=false]:first-child + span.button__label", text: "Bridge"
    assert_equal "Bridge", page.find("a.button").text.strip
  end

  test "an icon in a form button and a plain button" do
    render_inline(ButtonComponent.new(href: "/session", method: :delete, icon: "close")) { "Leave" }
    assert_selector "form button.button svg.pixel-icon + span.button__label", text: "Leave"

    render_inline(ButtonComponent.new(icon: "check")) { "Done" }
    assert_selector "button.button svg.pixel-icon + span.button__label", text: "Done"
  end

  test "a disabled button is always a plain disabled button, never a link or a form" do
    render_inline(ButtonComponent.new(href: "/en/packs", method: :post, disabled: true)) { "Open" }
    assert_selector "button.button.button--primary[type=button][disabled]", text: "Open"
    assert_no_selector "form"

    render_inline(ButtonComponent.new(variant: :secondary, href: "/en", disabled: true)) { "Back" }
    assert_selector "button.button--secondary[type=button][disabled]", text: "Back"
    assert_no_selector "a"

    render_inline(ButtonComponent.new(type: :submit, disabled: true)) { "Send" }
    assert_selector "button[type=button][disabled]"
  end

  test "a dialog opener is a plain button that opens the dialog it names" do
    render_inline(ButtonComponent.new(opens: "sign-in-panel")) { "Open my first capsules" }

    assert_selector "button.button.button--primary[type=button][aria-haspopup=dialog]", text: "Open my first capsules"
    assert_selector "button[data-controller=dialog-opener][data-action='dialog-opener#open'][data-dialog-opener-dialog-value=sign-in-panel]"
    assert_no_selector "form"
    assert_no_selector "a"
  end

  test "an aria label names every kind of button" do
    render_inline(ButtonComponent.new(href: "/en/trades/new", aria_label: "Propose a trade to Sam")) { "Propose a trade" }
    assert_selector "a[aria-label='Propose a trade to Sam']", text: "Propose a trade"

    render_inline(ButtonComponent.new(opens: "friend-x", aria_label: "See the profile of Sam")) { "See the profile" }
    assert_selector "button[aria-haspopup=dialog][aria-label='See the profile of Sam']"

    render_inline(ButtonComponent.new(href: "/session", method: :delete, aria_label: "Stand down, Sam")) { "Stand down" }
    assert_selector "form button[aria-label='Stand down, Sam']"

    render_inline(ButtonComponent.new(disabled: true, aria_label: "Send to Sam")) { "Send" }
    assert_selector "button[disabled][aria-label='Send to Sam']"

    render_inline(ButtonComponent.new(aria_label: "Report Sam")) { "Report" }
    assert_selector "button[aria-label='Report Sam']"
  end

  test "a dialog opener is neither a link nor disabled" do
    assert_raises(ArgumentError) { ButtonComponent.new(opens: "sign-in-panel", href: "/en") }
    assert_raises(ArgumentError) { ButtonComponent.new(opens: "sign-in-panel", disabled: true) }
  end
end
