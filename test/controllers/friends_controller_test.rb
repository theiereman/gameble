require "test_helper"

# The Friends screen (EXPERIENCE.md, Amis; story 5.1): the player's friend
# code and an empty friends list; a visitor is sent home to sign in.
class FriendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    OmniAuth.config.test_mode = true
    @player = accounts_players(:player)
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player = @player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    post "/auth/steam", params: { origin: "/en" }
    follow_redirect!
  end

  test "a player sees their code and an empty friends list" do
    sign_in

    get friends_path(locale: :fr)

    assert_response :success
    assert_select "title", /Amis/
    assert_select "main h1", "Amis"
    assert_select ".friends__label", "Votre code ami"
    assert_select ".friends__code", "7K2Q-F3NX"
    assert_select ".friends__empty"
    assert_select ".friends__row", 0
  end

  test "the friends are listed in English" do
    other = accounts_players(:moderator)
    other.update!(persona_name: "Sam")
    Game::Friendship.create!(low_player_id: [ @player.id, other.id ].min, high_player_id: [ @player.id, other.id ].max)
    sign_in

    get friends_path(locale: :en)

    assert_select "main h1", "Friends"
    assert_select ".friends__label", "Your friend code"
    assert_select ".friends__row", "Sam"
    assert_select ".friends__empty", 1, "only the no-invitation line"
  end

  test "a friend's name opens their profile dialog, whose frame loads the profile lazily (story 5.10)" do
    other = accounts_players(:moderator)
    other.update!(persona_name: "Sam")
    Game::Friendship.create!(low_player_id: [ @player.id, other.id ].min, high_player_id: [ @player.id, other.id ].max)
    sign_in

    get friends_path(locale: :fr)

    assert_select ".friends__row button.friends__name[aria-haspopup=dialog][data-dialog-opener-dialog-value=?]", "friend-#{other.token}", "Sam"
    assert_select "dialog#friend-#{other.token}.modal[aria-label=Sam]" do
      assert_select ".modal__title", "Profil"
      assert_select "turbo-frame#friend-profile-#{other.token}[loading=lazy][target=_top][src=?]",
        friend_profile_path(locale: :fr, token: other.token)
    end
  end

  test "a visitor is sent home to sign in" do
    get friends_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
  end

  test "menu 04 and the PLUS row lead a player to Amis" do
    sign_in

    get home_path(locale: :fr)
    assert_select ".hub-menu a.menu-item[href='/fr/friends'][aria-keyshortcuts='4']"
    get more_path(locale: :fr)
    assert_select ".plus__list a.menu-item[href='/fr/friends']", /Amis/
  end

  test "menu 04 and the PLUS row open the sign-in panel for a visitor" do
    get home_path(locale: :fr)
    assert_select ".hub-menu button.menu-item[aria-keyshortcuts='4'][aria-haspopup=dialog]", /Amis/
    get more_path(locale: :fr)
    assert_select ".plus__list button.menu-item[aria-haspopup=dialog]", /Amis/
  end
end
