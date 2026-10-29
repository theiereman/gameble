require "test_helper"
require_relative "../support/steam_sign_in"

class SignInsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  test "a visitor chooses how to sign in: Steam posts back to the page they came from" do
    get sign_in_path(locale: :fr, origin: "/fr/library")

    assert_response :success
    assert_select "h1", "Se connecter"
    assert_select "form.steam-sign-in[action='/auth/steam'][method=post][data-turbo=false]" do
      assert_select "input[name=origin][value='/fr/library']"
      assert_select "button.steam-sign-in__button img[src*='sits_01'][alt=?]", "Se connecter via Steam (ouvre Steam)"
    end
  end

  test "the terms and the privacy notice are named beside the options" do
    get sign_in_path(locale: :fr)

    assert_select "p.sign-in-acceptance",
      "En vous connectant, vous acceptez les conditions d'utilisation et prenez connaissance de la politique de confidentialité." do
      assert_select "a[href=?]", "/fr/legal#legal-terms"
      assert_select "a[href=?]", "/fr/legal#legal-privacy"
    end
  end

  test "an origin outside the site falls back to the bridge" do
    get sign_in_path(locale: :en, origin: "https://example.com/en")

    assert_select "form.steam-sign-in input[name=origin][value=?]", "/en"
  end

  test "a signed-in player is sent back to where they came from" do
    sign_in(accounts_players(:player))

    get sign_in_path(locale: :en, origin: "/en/library")
    assert_redirected_to "/en/library"

    get sign_in_path(locale: :en)
    assert_redirected_to home_path(locale: :en)
  end
end
