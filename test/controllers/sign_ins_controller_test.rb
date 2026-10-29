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

  test "the sign-in page lets Clerk's frontend API, its bot protection script and the captcha through" do
    get sign_in_callback_path(locale: :en)

    policy = response.headers["Content-Security-Policy"]
    frontend_api = Rails.configuration.x.clerk.frontend_api
    assert_match(/connect-src [^;]*https:\/\/#{Regexp.escape(frontend_api)}/, policy)
    assert_match(%r{script-src [^;]*https://cdn\.protect\.clerk\.com}, policy)
    assert_match(%r{script-src [^;]*https://challenges\.cloudflare\.com}, policy)
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

  test "Discord, Google and the email code sit beside Steam when Clerk is configured" do
    get sign_in_path(locale: :en, origin: "/en/library")

    assert_select "form.steam-sign-in"
    assert_select "[data-controller=clerk-sign-in]" do |roots|
      root = roots.first
      assert_equal Rails.configuration.x.clerk.publishable_key, root["data-clerk-sign-in-publishable-key-value"]
      assert_equal "start", root["data-clerk-sign-in-mode-value"]
      assert_match %r{/en/sign-in/callback\?origin=%2Fen%2Flibrary\z}, root["data-clerk-sign-in-callback-url-value"]
      assert_equal root["data-clerk-sign-in-callback-url-value"], root["data-clerk-sign-in-complete-url-value"]
      assert_includes JSON.parse(root["data-clerk-sign-in-messages-value"]).keys, "codeIncorrect"
      assert_select "button[data-action='clerk-sign-in#start'][data-clerk-sign-in-strategy-param=oauth_discord]", "Discord"
      assert_select "button[data-clerk-sign-in-strategy-param=oauth_google]", "Google"
      assert_select "form[data-action='submit->clerk-sign-in#sendCode'] input[type=email][data-clerk-sign-in-target=email]"
      assert_select "form[data-action='submit->clerk-sign-in#verifyCode'] input[data-clerk-sign-in-target=code]"
      assert_select "form[action='/en/auth/clerk'][method=post][data-turbo=false][data-clerk-sign-in-target=form] input[name=origin][value='/en/library']"
      assert_select "#clerk-captcha"
    end
    assert_select "[style]", 0
  end

  test "without a publishable key the screen offers Steam only" do
    key = Rails.configuration.x.clerk.publishable_key
    Rails.configuration.x.clerk.publishable_key = nil

    get sign_in_path(locale: :en)

    assert_response :success
    assert_select "form.steam-sign-in"
    assert_select "[data-controller=clerk-sign-in]", 0
  ensure
    Rails.configuration.x.clerk.publishable_key = key
  end

  test "the callback page finishes the sign-in: no buttons, the posting form and the origin" do
    get sign_in_callback_path(locale: :fr, origin: "/fr/library")

    assert_response :success
    assert_select "[data-clerk-sign-in-mode-value=callback]" do
      assert_select "button[data-clerk-sign-in-strategy-param]", 0
      assert_select "form[action='/fr/auth/clerk'][data-clerk-sign-in-target=form] input[name=origin][value='/fr/library']"
      assert_select "a[href=?]", "/fr/sign-in?origin=%2Ffr%2Flibrary"
    end
    assert_select "form.steam-sign-in", 0
  end

  test "the Clerk origins are allowed on the sign-in screen only" do
    get sign_in_path(locale: :en)
    api = "https://#{Rails.configuration.x.clerk.frontend_api}"
    connect = response.headers["Content-Security-Policy"].split(/;\s*/).find { it.start_with?("connect-src") }
    assert_includes connect.split, api

    get how_it_works_path(locale: :en)
    other = response.headers["Content-Security-Policy"].split(/;\s*/).find { it.start_with?("connect-src") }
    assert_not_includes other.split, api
  end
end
