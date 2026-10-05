require "test_helper"

class SteamSignInComponentTest < ViewComponent::TestCase
  test "a one-button POST form to Steam's sign-in, a full-page load, with its origin" do
    I18n.with_locale(:fr) { render_inline(SteamSignInComponent.new(origin: "/fr/library")) }

    assert_selector "form.steam-sign-in[action='/auth/steam'][method=post][data-turbo=false]"
    assert_selector "form input[type=hidden][name=origin][value='/fr/library']", visible: :all
    assert_selector "form button.steam-sign-in__button[type=submit]", count: 1
  end

  test "its button holds Valve's official image, unmodified, named for what it does" do
    I18n.with_locale(:en) { render_inline(SteamSignInComponent.new(origin: "/en")) }

    image = page.find("button.steam-sign-in__button img.steam-sign-in__image")
    assert_match %r{/sits_01-[\w-]+\.png\z}, image[:src]
    assert_equal [ "180", "35" ], [ image[:width], image[:height] ]
    assert_equal "Sign in through Steam (opens Steam)", image[:alt]
  end

  test "the image is the import, byte for byte" do
    assert_equal Rails.root.join("_bmad-output/initiative-gameble/ux-gameble/imports/sits_01.png").binread,
      Rails.root.join("app/frontend/images/steam/sits_01.png").binread
  end

  test "the button takes the focus first only when asked" do
    render_inline(SteamSignInComponent.new(origin: "/en"))
    assert_no_selector "button[autofocus]"

    render_inline(SteamSignInComponent.new(origin: "/en", autofocus: true))
    assert_selector "form.steam-sign-in button.steam-sign-in__button[autofocus]"
  end
end
