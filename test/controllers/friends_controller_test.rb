require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/steam_sign_in"

class FriendsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include CountingRateLimit
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

  test "each friend's name opens their profile and their row proposes a trade, both named for them" do
    sam = accounts_players(:moderator)
    sam.update!(persona_name: "Sam", visibility: "public")
    Game::Friendship.create!(low_player_id: [ @player.id, sam.id ].min, high_player_id: [ @player.id, sam.id ].max)
    sign_in(@player)

    get friends_path(locale: :fr)

    assert_select ".friends__friend" do
      assert_select "button.friends__name[type=button][aria-haspopup=dialog][aria-label='Voir le profil de Sam'][data-dialog-opener-dialog-value=?]", "friend-#{sam.token}", "Sam"
      assert_select ".friends__trade a.button.button--secondary[href=?][aria-label='Échange avec Sam']", new_trade_path(locale: :fr, friend: sam.token), "Échange"
      assert_select ".friends__trade a.button.button--secondary[href=?][aria-label='Voir la collection de Sam']", brother_collection_path(locale: :fr, token: sam.token), "Collection"
      assert_select ".button--primary", 0, "the row has no filled button"
      assert_select "button", text: "Voir le profil", count: 0
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

  test "each friend shows their presence, and menu 05 counts those online" do
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
      assert_select ".friends__friend:nth-child(1) .friends__presence--active", "Ouvre une capsule"
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

  test "a private friend reads Profil privé and is left out of menu 05's count" do
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

  test "menu 05 shows zero online for a player without friends, nothing for a visitor" do
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

    assert_select ".friends__friend button.friends__name[aria-haspopup=dialog][data-dialog-opener-dialog-value=?]", "friend-#{other.token}", "Sam"
    assert_select "dialog#friend-#{other.token}.modal[aria-label=Sam]" do
      assert_select ".modal__title", "Profil"
      assert_select "turbo-frame#friend-profile-#{other.token}[loading=lazy][target=_top][src=?]",
        friend_profile_path(locale: :fr, token: other.token)
    end
  end

  def befriend_sam
    sam = accounts_players(:moderator)
    sam.update!(persona_name: "Sam", visibility: "public")
    @player.update!(persona_name: "Lea")
    Game::Friendship.create!(low_player_id: [ @player.id, sam.id ].min, high_player_id: [ @player.id, sam.id ].max)
    sam
  end

  def open_trade_with(sam)
    portal = catalog_card_seasons(:portal_one).id
    soldier = catalog_card_seasons(:common_card_one).id
    Game::Holding.create!(player_id: @player.id, card_season_id: portal, quantity: 2, reserved: 0)
    Game::Holding.create!(player_id: sam.id, card_season_id: soldier, quantity: 1, reserved: 0)
    trade = Game::ProposeTrade.new.call(player: @player, recipient: sam, offer: { portal => 2 }, request: { soldier => 1 }).value!
    [ trade, Game::Holding.find_by(player_id: @player.id, card_season_id: portal) ]
  end

  test "each friend's more-actions menu offers to remove them, through a dialog that posts to their token and warns of a trade in progress only when there is one" do
    sam = befriend_sam
    sign_in(@player)

    get friends_path(locale: :fr)

    assert_select ".friends__friend .friends__more" do
      assert_select "button.friends__more-button[type=button][popovertarget=?][aria-label=?]", "friend-actions-#{sam.token}", "Plus d'actions pour Sam"
      assert_select "#friend-actions-#{sam.token}.friends__menu[popover][aria-label=?]", "Plus d'actions pour Sam" do
        assert_select "button.friends__menu-item[type=button][aria-haspopup=dialog][aria-label='Retirer Sam de vos amis'][data-dialog-opener-dialog-value=?]",
          "remove-friend-#{sam.token}", "Retirer"
      end
    end
    assert_select "dialog#remove-friend-#{sam.token}.modal[aria-labelledby=?][aria-describedby=?]", "remove-friend-#{sam.token}-title", "remove-friend-#{sam.token}-text" do
      assert_select "#remove-friend-#{sam.token}-title.modal__title", "Retirer Sam ?"
      assert_select "button.modal__close[aria-label=Fermer][data-action='dialog#close']"
      assert_select "form[method=post][action=?][data-turbo=false]", remove_friend_path(locale: :fr, token: sam.token) do
        assert_select "#remove-friend-#{sam.token}-text", /Sam quitte vos amis et vous quittez les siens\. Aucun message n'est envoyé/
        assert_select ".remove-friend-dialog__trade", 0
        assert_select "button.button--primary[type=submit]", "Retirer"
        assert_select "button.button--secondary[type=button][data-action='dialog#close']", "Annuler"
      end
    end

    open_trade_with(sam)
    get friends_path(locale: :fr)
    assert_select "dialog#remove-friend-#{sam.token} .remove-friend-dialog__trade", "Votre échange en cours avec Sam est annulé et ses cartes sont libérées."
    assert Game::FriendshipBetween.call(@player, sam), "the GET removes nothing"
  end

  test "a private friend's row still offers the removal in its more-actions menu beside the trades-closed line" do
    sam = befriend_sam
    sam.update!(visibility: "private")
    sign_in(@player)

    get friends_path(locale: :fr)

    assert_select ".friends__friend .friends__trade + .friends__more button[data-dialog-opener-dialog-value=?]", "remove-friend-#{sam.token}", "Retirer"

    sam.update!(visibility: "public")
    @player.update!(visibility: "private")
    get friends_path(locale: :fr)
    assert_select ".friends__friend .friends__trade .trades-closed", /Votre profil est privé/
    assert_select ".friends__friend .friends__trade a[href=?]", brother_collection_path(locale: :fr, token: sam.token)
    assert_select ".friends__friend .friends__trade + .friends__more button[data-dialog-opener-dialog-value=?]", "remove-friend-#{sam.token}", "Retirer"
  end

  test "only a private friend's more-actions menu offers the report, whose dialog sends back to Amis" do
    sam = befriend_sam
    sign_in(@player)

    get friends_path(locale: :fr)
    assert_select "#friend-actions-#{sam.token} button[data-dialog-opener-dialog-value=?]", "report-dialog-#{sam.token}", 0
    assert_select "dialog#report-dialog-#{sam.token}", 0

    sam.update!(visibility: "private")
    get friends_path(locale: :fr)

    assert_select "#friend-actions-#{sam.token} button.friends__menu-item[data-dialog-opener-dialog-value=?]", "report-dialog-#{sam.token}", "Signaler"
    assert_select "dialog#report-dialog-#{sam.token} form[action=?]", brother_report_path(locale: :fr, token: sam.token) do
      assert_select "input[type=hidden][name=from][value=friends]"
    end
  end

  test "a friend whose profile is private shows no collection button" do
    sam = accounts_players(:moderator)
    sam.update!(persona_name: "Sam", visibility: "private")
    Game::Friendship.create!(low_player_id: [ @player.id, sam.id ].min, high_player_id: [ @player.id, sam.id ].max)
    sign_in(@player)

    get friends_path(locale: :fr)

    assert_select ".friends__friend .friends__trade a[href=?]", brother_collection_path(locale: :fr, token: sam.token), 0
  end

  test "confirming the removal ends the friendship for both, cancels the trade in progress and frees its copies, silently for the former friend" do
    sam = befriend_sam
    trade, holding = open_trade_with(sam)
    assert_equal 2, holding.reserved
    sign_in(@player)
    get friend_profile_path(locale: :fr, token: sam.token)
    assert_response :success
    get feed_path(locale: :fr, tab: "friends")
    assert_select ".feed__no-friends", 0
    clear_enqueued_jobs

    post remove_friend_path(locale: :fr, token: sam.token)

    assert_redirected_to friends_path(locale: :fr)
    assert_response :see_other
    assert_not Game::FriendshipBetween.call(@player, sam)
    assert_equal "cancelled", trade.reload.status
    assert_equal 0, holding.reload.reserved
    stream_args = enqueued_jobs.select { it[:job] == PlayerStreamJob }.flat_map { ActiveJob::Arguments.deserialize(it[:args]).sole }
    assert_includes stream_args, { player_id: sam.id, topic: "friends" }
    assert_includes stream_args, { player_id: sam.id, topic: "trades" }
    assert stream_args.none? { it.key?(:friend_id) }, "no new-friend toast"

    follow_redirect!
    assert_select ".toasts > .toast--notice" do
      assert_select ".toast__title", "Ami retiré"
      assert_select ".toast__message", "Sam ne fait plus partie de vos amis."
    end
    assert_select ".friends__friend", 0
    get friend_profile_path(locale: :fr, token: sam.token)
    assert_response :not_found
    get feed_path(locale: :fr, tab: "friends")
    assert_select ".feed__no-friends"

    sign_in(sam)
    get friends_path(locale: :fr)
    assert_select ".friends__friend", 0
    assert_select ".toast__title", { text: "Ami retiré", count: 0 }
    assert_no_match(/ne fait plus partie/, response.body)
    get friend_profile_path(locale: :fr, token: @player.token)
    assert_response :not_found
    get feed_path(locale: :fr, tab: "friends")
    assert_select ".feed__no-friends"
  end

  test "removing a player who is not a friend changes nothing and says so" do
    sam = befriend_sam
    stranger = accounts_players(:administrator)
    sign_in(@player)

    post remove_friend_path(locale: :fr, token: stranger.token)
    assert_redirected_to friends_path(locale: :fr)
    follow_redirect!
    assert_select ".toasts > .toast--alert .toast__message", "Ce joueur ne fait pas partie de vos amis."

    post remove_friend_path(locale: :en, token: "a" * 24)
    follow_redirect!
    assert_select ".toasts > .toast--alert .toast__message", "This player is not one of your friends."
    assert Game::FriendshipBetween.call(@player, sam)
  end

  test "in English the removal reads in English" do
    sam = befriend_sam
    open_trade_with(sam)
    sign_in(@player)

    get friends_path(locale: :en)
    assert_select ".friends__friend button.friends__more-button[aria-label='More actions for Sam']"
    assert_select ".friends__friend button[aria-label='Remove Sam from your friends']", "Remove"
    assert_select "dialog#remove-friend-#{sam.token}" do
      assert_select ".modal__title", "Remove Sam?"
      assert_select ".remove-friend-dialog__trade", "Your trade in progress with Sam is cancelled and its cards are freed."
      assert_select "button[type=submit]", "Remove"
      assert_select "button[type=button]", "Cancel"
    end

    post remove_friend_path(locale: :en, token: sam.token)
    follow_redirect!
    assert_select ".toast__title", "Friend removed"
    assert_select ".toast__message", "Sam is no longer one of your friends."
  end

  test "a visitor cannot remove a friend" do
    sam = befriend_sam

    post remove_friend_path(locale: :fr, token: sam.token)

    assert_redirected_to home_path(locale: :fr)
    assert_nil flash[:alert]
    assert Game::FriendshipBetween.call(@player, sam)
  end

  test "removals are limited to 20 a minute" do
    sign_in(@player)

    with_counting_rate_limit(FriendsController) do
      21.times { post remove_friend_path(locale: :fr, token: "a" * 24) }
    end

    assert_redirected_to friends_path(locale: :fr)
    assert_equal I18n.t("friends.throttled", locale: :fr), flash[:alert]
  end

  test "a visitor is sent to the landing" do
    get friends_path(locale: :fr)

    assert_redirected_to home_path(locale: :fr)
  end

  test "menu 05 and the PLUS row lead a player to Amis" do
    sign_in(@player)

    get home_path(locale: :fr)
    assert_select ".hub-menu a.menu-item[href='/fr/friends'][aria-keyshortcuts='5']"
    get more_path(locale: :fr)
    assert_select ".plus__list a.menu-item[href='/fr/friends']", /Amis/
  end
end
