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

  test "a player without Steam changes their name from the settings" do
    sign_in_through_clerk

    get settings_path(locale: :en)
    assert_select "form[action=?] input[name=name]", "/en/settings/name"

    patch settings_name_path(locale: :en), params: { name: "  Gabe the Brave " }

    assert_redirected_to settings_path(locale: :en)
    assert_equal "Gabe the Brave", Accounts::Player.find(session[:player_id]).persona_name
  end

  test "an empty name is refused with a message" do
    sign_in_through_clerk

    patch settings_name_path(locale: :en), params: { name: "  " }

    assert_redirected_to settings_path(locale: :en)
    assert_equal I18n.t("errors.accounts.invalid_name", locale: :en), flash[:alert]
  end

  test "a Steam player has no name row and cannot change the name" do
    player = accounts_players(:player)
    sign_in(player)

    get settings_path(locale: :en)
    assert_select "input[name=name]", false

    patch settings_name_path(locale: :en), params: { name: "Other" }
    assert_equal I18n.t("errors.accounts.name_from_steam", locale: :en), flash[:alert]
    assert_not_equal "Other", player.reload.persona_name
  end

  test "a visitor cannot change a name" do
    patch settings_name_path(locale: :en), params: { name: "Other" }

    assert_redirected_to home_path(locale: :en)
  end
end
