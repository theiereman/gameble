require "test_helper"
require_relative "../support/steam_api_stubs"
require_relative "../support/steam_sign_in"
require_relative "../support/clerk_fake"

class SteamLinksControllerTest < ActionDispatch::IntegrationTest
  include ClerkFake
  include SteamApiStubs
  include SteamSignIn

  CLERK_USER = "user_discord".freeze
  STEAM_ID = "76561197960287930".freeze
  SETTINGS = "/en/settings".freeze

  setup do
    stub_steam_api
    stub_player_summary(STEAM_ID, "Gabe")
  end

  teardown { unstub_steam_api }

  def sign_in_through_clerk
    ClerkFake.install(users: {
      CLERK_USER => ClerkFake.api_user(CLERK_USER, accounts: [ { provider: "discord", uid: "discord-1", email: "mate@example.com" } ], email: "mate@example.com")
    })
    cookies["__session"] = ClerkFake.session_token(user_id: CLERK_USER)
    post clerk_session_path(locale: :en)
    Accounts::Player.find(session[:player_id])
  end

  def ask_to_link(locale: :en)
    post settings_steam_path(locale:), params: { origin: "/#{locale}/settings" }
    @steam_request = URI(response.location).request_uri if response.status == 307
  end

  # The browser posts the Steam form again where the 307 points, then Steam answers.
  def come_back_from_steam(steam_id = STEAM_ID, origin: SETTINGS, at: "/auth/steam")
    mock_steam_sign_in(steam_id)
    post at, params: { origin: }
    follow_redirect!
  end

  def link_steam(steam_id = STEAM_ID, locale: :en)
    ask_to_link(locale:)
    come_back_from_steam(steam_id, origin: "/#{locale}/settings", at: @steam_request)
  end

  test "asking to link Steam hands the same form over to the Steam sign-in" do
    sign_in_through_clerk

    ask_to_link

    assert_response :temporary_redirect
    assert_match %r{\Ahttp://www\.example\.com/auth/steam\?link=[\w-]{32}\z}, response.location
  end

  test "a Steam return that does not carry the link asked for links nothing to the signed-in player" do
    player = sign_in_through_clerk
    ask_to_link

    come_back_from_steam

    assert_not player.identities.exists?(provider: "steam")
    assert_not_equal player.id, session[:player_id]
  end

  test "a visitor cannot ask to link Steam, and a later Steam sign-in stays a sign-in" do
    ask_to_link

    assert_redirected_to home_path(locale: :en)
    come_back_from_steam
    assert_redirected_to home_path(locale: :en)
    assert_equal STEAM_ID, Accounts::Player.find(session[:player_id]).steam_id
  end

  test "a player coming back from Steam has Steam on their own account, in the same session" do
    player = sign_in_through_clerk

    assert_no_difference -> { Accounts::Player.count } do
      link_steam
    end

    assert_redirected_to settings_path(locale: :en)
    assert_equal I18n.t("sessions.create.steam_linked", locale: :en), flash[:notice]
    assert_equal player.id, session[:player_id]
    player.reload
    assert_predicate player.identities.where(provider: "steam", uid: STEAM_ID), :exists?
    assert_equal "Gabe", player.persona_name

    follow_redirect!
    assert_select "ul.sign-in-methods li", text: /Steam/
    assert_select "form[action=?]", "/en/settings/steam", 0
  end

  test "linking again the Steam account the player holds says so" do
    sign_in_through_clerk
    link_steam

    assert_no_difference -> { Accounts::Identity.count } do
      link_steam
    end

    assert_redirected_to settings_path(locale: :en)
    assert_equal I18n.t("sessions.create.steam_already_linked", locale: :en), flash[:notice]
  end

  test "a Steam account of another player is refused, nothing is linked and the player stays signed in" do
    player = sign_in_through_clerk
    taken = accounts_players(:player).steam_id

    assert_no_difference -> { Accounts::Identity.count } do
      link_steam(taken)
    end

    assert_redirected_to settings_path(locale: :en)
    assert_equal I18n.t("errors.accounts.steam_taken", locale: :en), flash[:alert]
    assert_equal player.id, session[:player_id]
    assert_not player.identities.exists?(provider: "steam")
  end

  test "in French the outcome speaks French" do
    sign_in_through_clerk

    link_steam(locale: :fr)

    assert_redirected_to settings_path(locale: :fr)
    assert_equal I18n.t("sessions.create.steam_linked", locale: :fr), flash[:notice]
  end

  test "a request whose player is gone by the Steam return signs in instead" do
    player = sign_in_through_clerk
    ask_to_link
    player.update_columns(banned_at: Time.current)

    come_back_from_steam(at: @steam_request)

    assert_redirected_to home_path(locale: :en)
    assert_not_equal player.id, session[:player_id]
    assert_equal STEAM_ID, Accounts::Player.find(session[:player_id]).steam_id
  end

  test "a Steam sign-in cancelled after asking to link drops the request: its return replayed later is refused" do
    player = sign_in_through_clerk
    ask_to_link

    get auth_failure_path(message: "invalid_credentials", origin: SETTINGS)

    assert_redirected_to settings_path(locale: :en)
    assert_equal I18n.t("errors.steam.sign_in_failed", locale: :en), flash[:alert]

    come_back_from_steam(origin: "/en", at: @steam_request)
    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("errors.steam.sign_in_failed", locale: :en), flash[:alert]
    assert_equal player.id, session[:player_id]
    assert_not player.identities.exists?(provider: "steam")
  end

  test "the settings offer Link Steam to a player without Steam only" do
    sign_in_through_clerk

    get settings_path(locale: :en)
    assert_select "form[action=?][data-turbo=false]", "/en/settings/steam" do
      assert_select "input[type=hidden][name=origin][value=?]", SETTINGS
      assert_select "button[type=submit]", "Link Steam"
    end

    delete session_path(locale: :en)
    sign_in(accounts_players(:player))
    get settings_path(locale: :en)
    assert_select "form[action=?]", "/en/settings/steam", 0
  end

  test "the Link Steam button speaks French" do
    sign_in_through_clerk

    get settings_path(locale: :fr)

    assert_select "form[action='/fr/settings/steam'] button", "Lier Steam"
  end
end
