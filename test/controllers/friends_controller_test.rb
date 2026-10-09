require "test_helper"

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
    assert_select ".friends__empty", /Aucun ami pour l'instant\./ do
      assert_select "a[href='#friends-invite']", "Invitez-en un avec votre lien ou votre code."
    end
    assert_select ".friends__panel#friends-invite .friends__heading", "Inviter un ami"
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
    assert_select ".friends__row .friends__name", "Sam"
    assert_select ".friends__row .friends__presence--offline", "Offline"
    assert_select ".friends__empty", 1, "only the no-invitation line"
  end

  test "each friend links to their public profile, named for them, unless their profile is private" do
    sam = accounts_players(:moderator)
    sam.update!(persona_name: "Sam", visibility: "public")
    lea = accounts_players(:administrator)
    lea.update!(persona_name: "Léa", visibility: "friends_only")
    [ sam, lea ].each { Game::Friendship.create!(low_player_id: [ @player.id, it.id ].min, high_player_id: [ @player.id, it.id ].max) }
    sign_in

    get friends_path(locale: :fr)
    assert_select ".friends__friend a.friends__profile-link[href='#{brother_path(locale: :fr, token: sam.token)}'][aria-label='Voir le profil de Sam']", "Voir le profil"
    assert_select ".friends__friend a.friends__profile-link[href='#{brother_path(locale: :fr, token: lea.token)}'][aria-label='Voir le profil de Léa']", "Voir le profil"

    lea.update!(visibility: "private")
    get friends_path(locale: :en)
    assert_select ".friends__friend a.friends__profile-link", 1
    assert_select ".friends__friend a.friends__profile-link[aria-label=\"See the profile of Sam\"]", "See the profile"
  end

  test "each friend shows their presence, and menu 04 counts those online" do
    now = Time.utc(2026, 10, 7, 15, 0)
    friends = { moderator: "Ada", administrator: "Bob" }.map do |key, name|
      friend = accounts_players(key)
      friend.update_columns(persona_name: name)
      low, high = [ @player.id, friend.id ].minmax
      Game::Friendship.create!(low_player_id: low, high_player_id: high)
      friend
    end
    ada, bob = friends

    travel_to(now) do
      Game::FillBank.new.call(player: ada).value!
      Game::OpenPack.new.call(player: ada).value!
      bob.update_columns(last_seen_at: now - 3.hours)
      sign_in

      get friends_path(locale: :fr)
      assert_select ".friends__friend", 2
      assert_select ".friends__friend:nth-child(1) .friends__name", "Ada"
      assert_select ".friends__friend:nth-child(1) .friends__presence--active", "Ouvre un booster"
      assert_select ".friends__friend:nth-child(2) .friends__presence--offline", "Il y a 3 h"
      assert_select ".friends__dot[aria-hidden=true]", 2

      get home_path(locale: :fr)
      assert_select ".hub-menu a.menu-item[href='/fr/friends'] .menu-item__meta", "1 en ligne"

      travel 6.minutes
      bob.update_columns(last_seen_at: Time.current)
      get friends_path(locale: :en)
      assert_select ".friends__friend:nth-child(1) .friends__presence--offline", "6 min ago"
      assert_select ".friends__friend:nth-child(2) .friends__presence--online", "Online"
      get home_path(locale: :en)
      assert_select ".hub-menu a.menu-item[href='/en/friends'] .menu-item__meta", "1 online"
    end
  end

  test "a private friend reads Profil privé and is left out of menu 04's count" do
    ada = accounts_players(:moderator)
    ada.update_columns(persona_name: "Ada", last_seen_at: Time.current, visibility: "private")
    low, high = [ @player.id, ada.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    sign_in

    get friends_path(locale: :fr)
    assert_select ".friends__friend .friends__presence--private", "Profil privé"
    get home_path(locale: :fr)
    assert_select ".hub-menu a.menu-item[href='/fr/friends'] .menu-item__meta", "0 en ligne"

    ada.update_columns(visibility: "friends_only")
    get friends_path(locale: :en)
    assert_select ".friends__friend .friends__presence--online", "Online"
    get home_path(locale: :fr)
    assert_select ".hub-menu a.menu-item[href='/fr/friends'] .menu-item__meta", "1 en ligne"
  end

  test "menu 04 shows zero online for a player without friends, nothing for a visitor" do
    get home_path(locale: :fr)
    assert_select ".hub-menu .menu-item__meta", { text: /en ligne/, count: 0 }

    sign_in
    get home_path(locale: :fr)
    assert_select ".hub-menu a.menu-item[href='/fr/friends'] .menu-item__meta", "0 en ligne"
  end

  test "a friend's name opens their profile dialog, whose frame loads the profile lazily" do
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
