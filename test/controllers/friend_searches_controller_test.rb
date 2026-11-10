require "test_helper"
require_relative "../support/steam_sign_in"

class FriendSearchesControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @alice = accounts_players(:player)
    @alice.update!(persona_name: "Lea")
    @bob = accounts_players(:moderator)
    @bob.update!(persona_name: "Sam")
  end

  test "a search lists players by name inside its frame, each one a button that invites them" do
    sign_in @alice

    get friend_search_path(locale: :fr, q: "sa"), headers: { "Turbo-Frame" => "friend-search-results" }

    assert_response :success
    assert_select "turbo-frame#friend-search-results" do
      assert_select "[data-friend-search-summary]", "1 joueur trouvé"
      assert_select "form[action=?] input[name=player][value=?]", invitations_path(locale: :fr), @bob.token
      assert_select "button.friend-search__pick[aria-label=?]", "Inviter Sam", text: /Sam/
    end
  end

  test "a friend or an invited player is listed without a button" do
    Game::SendInvitation.new.call(player: @alice, recipient_token: @bob.token)
    sign_in @alice

    get friend_search_path(locale: :fr, q: "sam")

    assert_select ".friend-search__pick--settled", /Sam.*Invité/m
    assert_select "button.friend-search__pick", 0
  end

  test "an empty search shows no result and the visitor is turned away" do
    sign_in @alice
    get friend_search_path(locale: :fr, q: "")
    assert_select ".friend-search__result", 0
    assert_select ".friend-search__none", 0

    get friend_search_path(locale: :fr, q: "zzz")
    assert_select ".friend-search__none", "Aucun joueur nommé «\u202Fzzz\u202F»."

    delete session_path
    get friend_search_path(locale: :fr, q: "sam")
    assert_response :redirect
  end
end
