require "test_helper"
require_relative "../support/steam_sign_in"

class FriendsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  test "a player sees their code and an empty friends list" do
    sign_in(@player)

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
    sign_in(@player)

    get friends_path(locale: :en)

    assert_select "main h1", "Friends"
    assert_select ".friends__label", "Your friend code"
    assert_select ".friends__row .friends__name", "Sam"
    assert_select ".friends__row .friends__presence--offline", "Offline"
    assert_select ".friends__empty", 1, "only the no-invitation line"
  end

  test "each friend's row opens their profile and proposes a trade, both named for them" do
    sam = accounts_players(:moderator)
    sam.update!(persona_name: "Sam", visibility: "public")
    Game::Friendship.create!(low_player_id: [ @player.id, sam.id ].min, high_player_id: [ @player.id, sam.id ].max)
    sign_in(@player)

    get friends_path(locale: :fr)

    assert_select ".friends__friend" do
      assert_select "span.friends__name", "Sam"
      assert_select "button.button[aria-haspopup=dialog][aria-label='Voir le profil de Sam'][data-dialog-opener-dialog-value=?]", "friend-#{sam.token}", "Voir le profil"
      assert_select "a.button[href=?][aria-label='Échange avec Sam']", new_trade_path(locale: :fr, friend: sam.token), "Échange"
      assert_select "a[href=?]", brother_path(locale: :fr, token: sam.token), 0
    end
  end

  test "a friend's row opens the trade in progress with them, whoever proposed it, and a new draft once it is closed" do
    sam = accounts_players(:moderator)
    sam.update!(persona_name: "Sam", visibility: "public")
    Game::Friendship.create!(low_player_id: [ @player.id, sam.id ].min, high_player_id: [ @player.id, sam.id ].max)
    portal = catalog_card_seasons(:portal_one).id
    soldier = catalog_card_seasons(:common_card_one).id
    Game::Holding.create!(player_id: sam.id, card_season_id: portal, quantity: 1, reserved: 0)
    Game::Holding.create!(player_id: @player.id, card_season_id: soldier, quantity: 1, reserved: 0)
    trade = Game::ProposeTrade.new.call(player: sam, recipient: @player, offer: { portal => 1 }, request: { soldier => 1 }).value!
    sign_in(@player)

    get friends_path(locale: :fr)
    assert_select ".friends__friend a.button[href=?][aria-label='Échange avec Sam']", trade_path(locale: :fr, token: trade.token), "Échange"
    assert_select ".friends__friend a[href=?]", new_trade_path(locale: :fr, friend: sam.token), 0

    Game::CancelTrade.new.call(player: sam, trade_id: trade.id).value!
    get friends_path(locale: :fr)
    assert_select ".friends__friend a.button[href=?]", new_trade_path(locale: :fr, friend: sam.token), "Échange"
  end

  test "a friend's row says trades are closed instead of proposing one when either profile is private" do
    lea = accounts_players(:administrator)
    lea.update!(persona_name: "Léa", visibility: "private")
    Game::Friendship.create!(low_player_id: [ @player.id, lea.id ].min, high_player_id: [ @player.id, lea.id ].max)
    sign_in(@player)

    get friends_path(locale: :fr)
    assert_select ".friends__friend .trades-closed", "Le profil de Léa est privé : échanges fermés."
    assert_select ".friends__friend a[href=?]", new_trade_path(locale: :fr, friend: lea.token), 0

    lea.update!(visibility: "public")
    @player.update!(visibility: "private")
    get friends_path(locale: :en)
    assert_select ".friends__friend .trades-closed", /Your profile is private: trades are closed\./ do
      assert_select "a.trades-closed__link[href=?]", settings_path(locale: :en)
    end
    assert_select ".friends__friend a[href=?]", new_trade_path(locale: :en, friend: lea.token), 0
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
      sign_in(@player)

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
    sign_in(@player)

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

    sign_in(@player)
    get home_path(locale: :fr)
    assert_select ".hub-menu a.menu-item[href='/fr/friends'] .menu-item__meta", "0 en ligne"
  end

  test "a friend's profile button opens their profile dialog, whose frame loads the profile lazily" do
    other = accounts_players(:moderator)
    other.update!(persona_name: "Sam")
    Game::Friendship.create!(low_player_id: [ @player.id, other.id ].min, high_player_id: [ @player.id, other.id ].max)
    sign_in(@player)

    get friends_path(locale: :fr)

    assert_select ".friends__row button[aria-haspopup=dialog][data-dialog-opener-dialog-value=?]", "friend-#{other.token}", "Voir le profil"
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
    sign_in(@player)

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
