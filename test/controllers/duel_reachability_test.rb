require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/live_duels"

# Who can be challenged right now: Duels' EN LIGNE section and the DÉFIER EN DUEL control on the friend's row, the friend
# profile and the public profile.
class DuelReachabilityPagesTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include LiveDuels

  setup do
    @lea = accounts_players(:player)
    @hugo = accounts_players(:moderator)
    @hugo.update!(persona_name: "Hugo", visibility: "public")
    sign_in(@lea)
  end

  def reachable_hugo = befriend(@lea, @hugo)

  def invite_hugo
    Game::DuelSeat.create!(duel: Game::Duel.create!, role: "opponent", player_id: @hugo.id, status: "invited")
  end

  test "Duels lists the reachable friends with a button that preselects them" do
    reachable_hugo
    complete_deck(@lea, "Lea")

    get duels_path(locale: :fr)

    assert_select "#duel-online-heading", "En ligne · 1"
    assert_select ".duel-online__row" do
      assert_select ".player-name", "Hugo"
      assert_select "a.button[aria-label='Défier Hugo'][href$='friend=#{@hugo.token}#duel-challenge']", "Défier"
    end
    assert_select "input[type=radio][name=friend][value='#{@hugo.token}'][checked]"
  end

  test "the friend named in the link is the one selected, an unknown token is ignored" do
    reachable_hugo
    max = accounts_players(:administrator)
    max.update!(persona_name: "Max")
    befriend(@lea, max)
    complete_deck(@lea, "Lea")

    get duels_path(locale: :en, friend: max.token)
    assert_select "input[type=radio][name=friend][checked]", 1
    assert_select "input[type=radio][name=friend][value='#{max.token}'][checked]"

    get duels_path(locale: :en, friend: "nope")
    assert_select "input[type=radio][name=friend][checked]", 1
  end

  test "a friend in a duel is named without a button" do
    reachable_hugo
    invite_hugo

    get duels_path(locale: :fr)

    assert_select ".duel-online__row .duel-online__note", "Duel en cours"
    assert_select ".duel-online__row a.button", 0
  end

  test "no friend online, no friend, a private own profile" do
    reachable_hugo
    @hugo.update_columns(reachable_until: 1.minute.ago)
    get duels_path(locale: :fr)
    assert_select "#duel-online-heading", "En ligne · 0"
    assert_select ".duel-lobby__line", "Aucun ami en ligne pour l'instant."

    Game::Friendship.delete_all
    get duels_path(locale: :fr)
    assert_select ".duel-lobby__line", "Ajoutez des amis pour les défier."
    assert_select "a.button[href='/fr/friends']", "Ajouter des amis"

    reachable_hugo
    @lea.update_columns(visibility: "private")
    get duels_path(locale: :fr)
    assert_select ".duel-lobby__line", count: 1, text: "Vos duels sont fermés tant que votre profil est privé."
    assert_select "#duel-online-heading", 0
  end

  test "the friend's row and profile offer DÉFIER EN DUEL after the trade, and say when he is in a duel" do
    reachable_hugo

    get friends_path(locale: :fr)
    assert_select ".friends__friend a.button[aria-label='Défier Hugo en duel'][href$='friend=#{@hugo.token}#duel-challenge']", "Défier en duel"

    get friend_profile_path(locale: :fr, token: @hugo.token)
    assert_select ".friend-profile__trade a.button[aria-label='Défier Hugo en duel']", "Défier en duel"

    invite_hugo
    get friends_path(locale: :fr)
    assert_select ".friends__friend a.button[aria-label='Défier Hugo en duel']", 0
    assert_select ".friends__friend .duel-online__note", "Duel en cours"
  end

  test "the public profile of a reachable friend offers it too" do
    reachable_hugo

    get brother_path(locale: :fr, token: @hugo.token)

    assert_select "a.button[aria-label='Défier Hugo en duel']", "Défier en duel"
  end

  test "a lapsed friend has no button, a private friend has the closed line" do
    reachable_hugo
    @hugo.update_columns(reachable_until: 1.minute.ago)

    get friends_path(locale: :fr)
    assert_select "a.button[aria-label='Défier Hugo en duel']", 0

    @hugo.update_columns(reachable_until: 1.day.from_now, visibility: "private")
    get friends_path(locale: :fr)
    assert_select "a.button[aria-label='Défier Hugo en duel']", 0
    assert_select ".friends__friend .trades-closed", "Duels fermés tant que ce profil est privé."
  end
end
