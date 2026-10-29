require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/clerk_fake"

class ClerkSessionsControllerTest < ActionDispatch::IntegrationTest
  include ClerkFake
  include SteamSignIn

  CLERK_USER = "user_discord".freeze

  setup do
    @clerk = ClerkFake.install(users: {
      CLERK_USER => ClerkFake.api_user(CLERK_USER, accounts: [ { provider: "discord", uid: "discord-1", email: "mate@example.com" } ], email: "mate@example.com")
    })
  end

  def present_clerk_session(user_id: CLERK_USER, **options)
    cookies["__session"] = ClerkFake.session_token(user_id:, **options)
  end

  def new_players
    Accounts::Player.where.not(id: accounts_players.map(&:id))
  end

  test "a verified Clerk session opens the app session of a new player and lands on the origin" do
    present_clerk_session

    assert_difference -> { new_players.count }, 1 do
      post clerk_session_path(locale: :en), params: { origin: "/en/library" }
    end

    assert_redirected_to "/en/library"
    player = new_players.sole
    assert_equal player.id, session[:player_id]
    assert_predicate player.identities.where(provider: "discord", uid: "discord-1"), :exists?
  end

  test "a returning player is the same player and goes home without an origin" do
    present_clerk_session
    post clerk_session_path(locale: :en)
    player_id = session[:player_id]
    delete session_path(locale: :en)

    present_clerk_session
    assert_no_difference -> { new_players.count } do
      post clerk_session_path(locale: :en)
    end

    assert_equal player_id, session[:player_id]
    assert_redirected_to home_path(locale: :en)
  end

  test "an origin outside the site is dropped" do
    present_clerk_session

    post clerk_session_path(locale: :en), params: { origin: "https://example.com/en" }

    assert_redirected_to home_path(locale: :en)
  end

  test "a missing cookie is refused with the alert, nothing is written and no session opens" do
    assert_no_difference -> { Accounts::Player.count } do
      post clerk_session_path(locale: :fr), params: { origin: "/fr/library" }
    end

    assert_redirected_to sign_in_path(locale: :fr, origin: "/fr/library")
    assert_equal I18n.t("errors.accounts.invalid_session", locale: :fr), flash[:alert]
    assert_nil session[:player_id]
  end

  test "a forged cookie is refused" do
    cookies["__session"] = "forged.token.value"

    assert_no_difference -> { Accounts::Player.count } do
      post clerk_session_path(locale: :en)
    end

    assert_redirected_to sign_in_path(locale: :en)
    assert_equal I18n.t("errors.accounts.invalid_session", locale: :en), flash[:alert]
    assert_nil session[:player_id]
  end

  test "a token for another page origin is refused" do
    present_clerk_session(azp: "https://attacker.example")

    post clerk_session_path(locale: :en)

    assert_redirected_to sign_in_path(locale: :en)
    assert_nil session[:player_id]
  end

  test "Clerk being down gives its alert" do
    present_clerk_session
    @clerk.unavailable = true

    post clerk_session_path(locale: :en)

    assert_redirected_to sign_in_path(locale: :en)
    assert_equal I18n.t("errors.accounts.clerk_unavailable", locale: :en), flash[:alert]
  end

  test "an email already known through another provider is refused naming it" do
    steam_owner = accounts_players(:player)
    steam_owner.identities.create!(provider: "google", uid: "google-9", email_hash: Accounts::EmailHash.call("mate@example.com"))
    present_clerk_session

    assert_no_difference -> { new_players.count } do
      post clerk_session_path(locale: :en)
    end

    assert_redirected_to sign_in_path(locale: :en)
    assert_equal I18n.t("errors.accounts.email_known_google", locale: :en), flash[:alert]
  end

  test "a banned player gets the suspension notice and no session" do
    banned = accounts_players(:banned)
    banned.identities.create!(provider: "discord", uid: "discord-1")
    present_clerk_session

    post clerk_session_path(locale: :en)

    assert_response :forbidden
    assert_select "h1", I18n.t("sessions.banned.title", locale: :en)
    assert_includes response.body, I18n.t("errors.accounts.banned", locale: :en)
    assert_nil session[:player_id]
  end

  test "a banned player who signed in through Clerk is shown the reason of the ban" do
    banned = accounts_players(:banned)
    banned.identities.create!(provider: "discord", uid: "discord-1", clerk_user_id: CLERK_USER)
    Accounts::ModerationAction.create!(kind: :ban, player: banned, staff: accounts_players(:moderator), reason: "Insults in the name")
    present_clerk_session

    post clerk_session_path(locale: :en)

    assert_response :forbidden
    assert_select ".account-suspended__reason", "Insults in the name"
  end

  test "a signed-in session is replaced by the new one" do
    sign_in(accounts_players(:player))
    old_session_id = session.id.to_s
    present_clerk_session

    post clerk_session_path(locale: :en)

    assert_not_equal accounts_players(:player).id, session[:player_id]
    assert_not_equal old_session_id, session.id.to_s
  end
end
