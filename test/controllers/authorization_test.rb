require "test_helper"
require_relative "../support/steam_sign_in"

# A controller action that forgets its policy decision.
class UnguardedController < ApplicationController
  def show
    render plain: "unguarded"
  end
end

# A controller action every player is refused, to see the 403.
class StaffOnlyController < ApplicationController
  def show
    authorize :page, :update?
    render plain: "staff"
  end
end

class AuthorizationTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  # The app's routes the tests need, plus the test-only controllers.
  def with_test_routes
    with_routing do |set|
      set.draw do
        scope ":locale", locale: /en|fr/ do
          root "pages#home", as: :home
        end
        get "unguarded" => "unguarded#show"
        get "staff_only" => "staff_only#show"
        resource :session, only: :destroy
        get "auth/steam/callback" => "sessions#create"
      end
      yield
    end
  end

  test "a visitor may read an open page" do
    get how_it_works_path(locale: :fr)

    assert_response :success
  end

  test "a visitor's HTML request for a player's page is sent to the landing, without an alert" do
    get more_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_response :see_other
    assert_nil flash[:alert]
  end

  test "a visitor's JSON request for a player's page answers 401 sign_in_required" do
    get more_path(locale: :en), headers: { "Accept" => "application/json" }

    assert_response :unauthorized
    assert_equal "sign_in_required", response.parsed_body.dig("error", "code")
  end

  test "a visitor's sign-out is refused and sent to the landing" do
    delete session_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
    assert_nil flash[:alert]
    assert_nil flash[:notice]
  end

  test "a visitor's JSON sign-out answers 401 with the error shape" do
    delete session_path(locale: :en), headers: { "Accept" => "application/json" }

    assert_response :unauthorized
    assert_equal(
      { "error" => { "code" => "sign_in_required", "message" => I18n.t("authorization.sign_in_required", locale: :en) } },
      response.parsed_body
    )
  end

  test "a player signs out" do
    sign_in(accounts_players(:player))

    delete session_path(locale: :en)

    assert_nil session[:player_id]
    assert_redirected_to home_path(locale: :en)
    assert_equal I18n.t("sessions.destroy.farewell", locale: :en), flash[:notice]
  end

  test "a player banned meanwhile is signed out on their next request" do
    player = accounts_players(:player)
    sign_in(player)

    player.update_columns(banned_at: Time.current)
    get how_it_works_path(locale: :fr)

    assert_response :success
    assert_nil session[:player_id]
    assert_select ".top-bar__end form[action='/auth/steam']"
    assert_select ".top-bar form[action^='/session']", false
  end

  test "a player banned meanwhile cannot sign out as if still signed in" do
    player = accounts_players(:player)
    sign_in(player)

    player.update_columns(banned_at: Time.current)
    delete session_path(locale: :en)

    assert_nil session[:player_id]
    assert_redirected_to home_path(locale: :en)
    assert_nil flash[:alert]
  end

  test "from a banned player's session, another player signs in" do
    banned = accounts_players(:player)
    sign_in(banned)
    banned.update_columns(banned_at: Time.current)

    sign_in(accounts_players(:moderator))

    assert_equal I18n.t("sessions.create.welcome", locale: :en), flash[:notice]
  end

  test "from their own live session, a banned player signing in again is told they are banned, signed out" do
    banned = accounts_players(:player)
    sign_in(banned)
    banned.update_columns(banned_at: Time.current)

    mock_steam_sign_in(banned.steam_id)
    post "/auth/steam", params: { origin: "/en" }
    follow_redirect!

    assert_nil session[:player_id]
    assert_response :forbidden
    assert_select ".account-suspended__lead", I18n.t("errors.accounts.banned", locale: :en)
    assert_select ".top-bar .steam-sign-in"
  end

  test "a player banned by a moderator is refused at sign-in, and signs in again once unbanned" do
    player = accounts_players(:player)
    moderator = accounts_players(:moderator)
    Accounts::BanPlayer.new.call(staff: moderator, player:, reason: "Cheating").value!

    mock_steam_sign_in(player.steam_id)
    post "/auth/steam", params: { origin: "/en" }
    follow_redirect!

    assert_nil session[:player_id]
    assert_response :forbidden
    assert_select ".account-suspended__reason", "Cheating"

    Accounts::UnbanPlayer.new.call(staff: moderator, player:).value!
    sign_in(player)

    assert_equal I18n.t("sessions.create.welcome", locale: :en), flash[:notice]
  end

  test "a refused player gets 403 with the translated message" do
    with_test_routes do
      sign_in(accounts_players(:player))

      get "/staff_only", params: { locale: "fr" }

      assert_response :forbidden
      assert_includes response.body, ERB::Util.html_escape(I18n.t("authorization.forbidden", locale: :fr))
    end
  end

  test "a refused player's JSON request gets 403 with the error shape" do
    with_test_routes do
      sign_in(accounts_players(:player))

      get "/staff_only", params: { locale: "en" }, headers: { "Accept" => "application/json" }

      assert_response :forbidden
      assert_equal "forbidden", response.parsed_body.dig("error", "code")
    end
  end

  test "an action that never calls authorize fails" do
    with_test_routes do
      assert_raises(Pundit::AuthorizationNotPerformedError) { get "/unguarded" }
    end
  end
end
