require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/clerk_fake"

class SettingsNameTest < ActionDispatch::IntegrationTest
  include ClerkFake
  include SteamSignIn

  CLERK_USER = "user_discord".freeze

  def sign_in_through_clerk
    ClerkFake.install(users: {
      CLERK_USER => ClerkFake.api_user(CLERK_USER, accounts: [ { provider: "discord", uid: "discord-1", email: "mate@example.com" } ], email: "mate@example.com")
    })
    cookies["__session"] = ClerkFake.session_token(user_id: CLERK_USER)
    post clerk_session_path(locale: :en)
    assert session[:player_id]
  end

  def own_profile_path = brother_path(locale: :en, token: Accounts::Player.find(session[:player_id]).token)

  test "a player without Steam changes their name from the pen of their own profile" do
    sign_in_through_clerk

    get own_profile_path
    assert_select ".profile-band__line button.profile-pen[data-dialog-opener-dialog-value=profile-name-dialog]"
    assert_select "dialog#profile-name-dialog form[action=?] input[name=name]", "/en/settings/name"
    get settings_path(locale: :en)
    assert_select "input[name=name]", false

    patch settings_name_path(locale: :en), params: { name: "  Gabe the Brave " }

    assert_redirected_to own_profile_path
    assert_equal "Gabe the Brave", Accounts::Player.find(session[:player_id]).persona_name
  end

  test "an empty name is refused with a message" do
    sign_in_through_clerk

    patch settings_name_path(locale: :en), params: { name: "  " }

    assert_redirected_to own_profile_path
    assert_equal I18n.t("errors.accounts.invalid_name", locale: :en), flash[:alert]
  end

  test "a Steam player has no name pen and cannot change the name" do
    player = accounts_players(:player)
    sign_in(player)

    get brother_path(locale: :en, token: player.token)
    assert_select "#profile-name-dialog, input[name=name]", false

    patch settings_name_path(locale: :en), params: { name: "Other" }
    assert_equal I18n.t("errors.accounts.name_from_steam", locale: :en), flash[:alert]
    assert_not_equal "Other", player.reload.persona_name
  end

  test "a visitor cannot change a name" do
    patch settings_name_path(locale: :en), params: { name: "Other" }

    assert_redirected_to home_path(locale: :en)
  end
end
