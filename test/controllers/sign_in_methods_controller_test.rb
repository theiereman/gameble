require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/clerk_fake"

class SignInMethodsControllerTest < ActionDispatch::IntegrationTest
  include ClerkFake
  include SteamSignIn

  CLERK_USER = "user_google".freeze

  setup do
    ClerkFake.install(users: {
      CLERK_USER => ClerkFake.api_user(CLERK_USER, accounts: [ { provider: "google", uid: "google-1", email: "mate@example.com" } ], email: "mate@example.com")
    })
  end

  def present_clerk_session
    cookies["__session"] = ClerkFake.session_token(user_id: CLERK_USER)
  end

  test "a signed-in player adds the identity to their own account" do
    player = accounts_players(:player)
    sign_in(player)
    present_clerk_session

    assert_difference -> { player.identities.count }, 1 do
      post settings_sign_ins_path(locale: :en)
    end

    assert_redirected_to settings_path(locale: :en)
    assert_equal I18n.t("sign_in_methods.create.added", locale: :en), flash[:notice]
    assert_predicate player.identities.where(provider: "google", uid: "google-1"), :exists?
  end

  test "an identity owned by another player is refused and nothing moves" do
    accounts_players(:moderator).identities.create!(provider: "google", uid: "google-1")
    player = accounts_players(:player)
    sign_in(player)
    present_clerk_session

    assert_no_difference -> { Accounts::Identity.count } do
      post settings_sign_ins_path(locale: :en)
    end

    assert_redirected_to settings_path(locale: :en)
    assert_equal I18n.t("errors.accounts.identity_taken", locale: :en), flash[:alert]
  end

  test "a missing or forged cookie is refused with the alert" do
    sign_in(accounts_players(:player))
    cookies["__session"] = "forged"

    assert_no_difference -> { Accounts::Identity.count } do
      post settings_sign_ins_path(locale: :en)
    end

    assert_redirected_to settings_path(locale: :en)
    assert_equal I18n.t("errors.accounts.invalid_session", locale: :en), flash[:alert]
  end

  test "a visitor is refused and nothing is written" do
    present_clerk_session

    assert_no_difference -> { Accounts::Identity.count } do
      post settings_sign_ins_path(locale: :en)
    end

    assert_redirected_to home_path(locale: :en)
    assert_nil session[:player_id]
  end

  test "the settings list the player's sign-ins and offer the Clerk options" do
    player = accounts_players(:player)
    player.identities.create!(provider: "discord", uid: "discord-7")
    sign_in(player)

    get settings_path(locale: :en)

    assert_response :success
    assert_select "ul.sign-in-methods li.sign-in-methods__item", 2
    assert_select "ul.sign-in-methods li", text: /Steam/
    assert_select "ul.sign-in-methods li", text: /Discord/
    assert_select "[data-controller=clerk-sign-in][data-clerk-sign-in-mode-value=start]" do
      assert_select "button[data-clerk-sign-in-strategy-param=oauth_discord]"
      assert_select "button[data-clerk-sign-in-strategy-param=oauth_google]"
      assert_select "form[action=?][data-turbo=false][data-clerk-sign-in-target=form]", "/en/settings/sign-ins"
    end
    assert_select "[data-clerk-sign-in-callback-url-value$='/en/settings?add_sign_in=1']"
    assert_select "[style]", 0
  end

  test "the settings come back from Clerk in callback mode" do
    sign_in(accounts_players(:player))

    get settings_path(locale: :en, add_sign_in: 1)

    assert_select "[data-clerk-sign-in-mode-value=callback]"
    assert_select "button[data-clerk-sign-in-strategy-param]", 0
  end

  test "the settings without a publishable key list the sign-ins only" do
    sign_in(accounts_players(:player))
    key = Rails.configuration.x.clerk.publishable_key
    Rails.configuration.x.clerk.publishable_key = nil

    get settings_path(locale: :en)

    assert_response :success
    assert_select "ul.sign-in-methods li", 1
    assert_select "[data-controller=clerk-sign-in]", 0
  ensure
    Rails.configuration.x.clerk.publishable_key = key
  end
end
