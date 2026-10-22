require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

class FriendProfilesControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include LibraryRequests
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    @friend.update_columns(persona_name: "Léa")
    Game::Friendship.create!(low_player_id: [ @player.id, @friend.id ].min, high_player_id: [ @player.id, @friend.id ].max)
  end

  def frame_id(player) = "friend-profile-#{player.token}"

  def unavailable_frame(token)
    assert_response :not_found
    assert_select "turbo-frame#friend-profile-#{token}[target=_top] .friend-profile--unavailable", 1
    assert_select ".friend-profile__showcase, .friend-profile__actions, .friends__collection-link", false
    css_select("turbo-frame").to_html.gsub(token, "TOKEN")
  end

  test "a friend sees the name, the count, no showcase, the trade action, the profile and the collection links and SIGNALER" do
    season = publish_sets_draft
    tiers = Catalog::CardSeason.where(season_id: season.id).order(:id).pluck(:rarity, :id)
      .group_by(&:first).transform_values { |rows| rows.map(&:last) }
    hold(@friend, tiers.fetch("common").first, 2)
    hold(@friend, tiers.fetch("legendary").first, 1)
    hold(@friend, tiers.fetch("epic").first, 1, gained_at: 2.days.ago)
    hold(@friend, tiers.fetch("rare").first, 1)
    sign_in(@player)

    get friend_profile_path(locale: :fr, token: @friend.token)

    assert_response :success
    assert_select "turbo-frame##{frame_id(@friend)}[target=_top]" do
      assert_select ".friend-profile__name", "Léa"
      assert_select "svg.friend-profile__avatar"
      assert_select ".friend-profile__presence .friends__presence--offline", "Hors ligne"
      assert_select ".friend-profile__count", "4 cartes collectionnées"
      assert_select ".friend-profile__heading, .friend-profile__showcase", false
      assert_select ".friend-profile__actions a.friends__profile-link[href=?]", brother_path(locale: :fr, token: @friend.token), "Voir le profil"
      assert_select ".friend-profile__actions a.friends__collection-link[href=?]", brother_collection_path(locale: :fr, token: @friend.token), "Voir la collection"
      assert_select ".friend-profile__actions a.button--primary[href=?]", new_trade_path(locale: :fr, friend: @friend.token), "Échange"
      assert_select ".friend-profile__actions button.button--link[aria-haspopup=dialog][data-dialog-opener-dialog-value=?]",
        "report-dialog-#{@friend.token}", "SIGNALER"
      assert_select "dialog#report-dialog-#{@friend.token} form[action=?]", brother_report_path(locale: :fr, token: @friend.token) do
        assert_select "input[type=hidden][name=from][value=friends]"
      end
    end
    assert_not_includes response.body, @friend.steam_id
  end

  test "a friend's count is their games in any edition, one held twice counted once" do
    publish_sets_draft
    portal = catalog_card_seasons(:portal_one)
    reprint = Catalog::CardSeason.find_by!(season_id: Catalog::PublishedSeason.call.id, number: 1)
    hold(@friend, portal.id, 1)
    hold(@friend, reprint.id, 1)
    hold(@friend, Catalog::CardSeason.insert_all!([ { card_id: reprint.card_id, season_id: catalog_seasons(:one).id, prestige_score: 0.5,
      rating: 90, rarity: "rare", number: 900 } ], returning: :id).rows.flatten.sole, 1)
    sign_in(@player)

    get friend_profile_path(locale: :en, token: @friend.token)

    assert_select ".friend-profile__count", "2 cards collected"
  end

  test "a friend holding nothing shows no showcase, in English" do
    publish_sets_draft
    @friend.update_columns(last_seen_at: 1.minute.ago)
    sign_in(@player)

    get friend_profile_path(locale: :en, token: @friend.token)

    assert_response :success
    assert_select ".friend-profile__count", "0 cards collected"
    assert_select ".friend-profile__presence .friends__presence--online", "Online"
    assert_select ".friend-profile__showcase, .friend-profile__empty", false
    assert_select ".friend-profile__actions a.button--primary[href=?]", new_trade_path(locale: :en, friend: @friend.token), "Trade"
  end

  test "a friends-only friend is shown; a private one is the not-available frame" do
    @friend.update!(visibility: "friends_only")
    sign_in(@player)

    get friend_profile_path(locale: :en, token: @friend.token)
    assert_response :success
    assert_select ".friend-profile__name", "Léa"
    assert_select ".friend-profile__actions a.friends__profile-link[href='#{brother_path(locale: :en, token: @friend.token)}'][aria-label=\"See Léa's profile\"]", "See the profile"
    assert_select ".friend-profile__actions a.friends__collection-link[href='#{brother_collection_path(locale: :en, token: @friend.token)}'][aria-label=\"See Léa's collection\"]", "See the collection"

    @friend.update!(visibility: "private")
    get friend_profile_path(locale: :en, token: @friend.token)
    unavailable_frame(@friend.token)
    assert_select "a.friends__profile-link, a.friends__collection-link", false
    assert_select ".friend-profile__empty", "This profile is not available."
    assert_not_includes response.body, "Léa"
  end

  test "a friends-only player still gets the trade action on a friend's profile" do
    @player.update!(visibility: "friends_only")
    sign_in(@player)

    get friend_profile_path(locale: :fr, token: @friend.token)

    assert_response :success
    assert_select ".friend-profile__actions a.button--primary[href=?]", new_trade_path(locale: :fr, friend: @friend.token), "Échange"
    assert_select ".trades-closed", 0
  end

  test "a friend's profile opens the trade in progress with them, whoever proposed it, and a new draft once it is closed" do
    portal = catalog_card_seasons(:portal_one).id
    soldier = catalog_card_seasons(:common_card_one).id
    hold(@friend, portal, 1)
    hold(@player, soldier, 1)
    trade = Game::ProposeTrade.new.call(player: @friend, recipient: @player, offer: { portal => 1 }, request: { soldier => 1 }).value!
    sign_in(@player)

    get friend_profile_path(locale: :fr, token: @friend.token)
    assert_select ".friend-profile__actions a.button--primary[href=?]", trade_path(locale: :fr, token: trade.token), "Échange"
    assert_select ".friend-profile__actions a[href=?]", new_trade_path(locale: :fr, friend: @friend.token), 0

    Game::CancelTrade.new.call(player: @friend, trade_id: trade.id).value!
    get friend_profile_path(locale: :fr, token: @friend.token)
    assert_select ".friend-profile__actions a.button--primary[href=?]", new_trade_path(locale: :fr, friend: @friend.token), "Échange"
  end

  test "a private player still sees a friend's profile, with the trades-closed line instead of the trade action" do
    @player.update!(visibility: "private")
    sign_in(@player)

    get friend_profile_path(locale: :fr, token: @friend.token)

    assert_response :success
    assert_select ".friend-profile__actions a.friends__collection-link", "Voir la collection"
    assert_select ".friend-profile__actions a.button--primary", 0
    assert_select ".friend-profile__actions .trades-closed", /Votre profil est privé : les échanges sont fermés\./
    assert_select ".friend-profile__actions .trades-closed a[href=?]", settings_path(locale: :fr), "RÉGLAGES"
    assert_select ".friend-profile__actions button.button--link", "SIGNALER"
  end

  test "a public player who is not a friend, a banned friend and an unknown token answer the same" do
    stranger = accounts_players(:administrator)
    banned = accounts_players(:banned)
    Game::Friendship.create!(low_player_id: [ @player.id, banned.id ].min, high_player_id: [ @player.id, banned.id ].max)
    sign_in(@player)

    get friend_profile_path(locale: :en, token: "1" * 24)
    unknown = unavailable_frame("1" * 24)

    [ stranger, banned, @player ].each do |owner|
      get friend_profile_path(locale: :en, token: owner.token)
      assert_equal unknown, unavailable_frame(owner.token), owner.token
    end
  end

  test "staff see a friend's profile as a player would: a private or banned friend is the not-available frame" do
    banned = accounts_players(:banned)
    Game::Friendship.create!(low_player_id: [ @friend.id, banned.id ].min, high_player_id: [ @friend.id, banned.id ].max)
    @player.update!(visibility: "private")
    sign_in(@friend)

    get friend_profile_path(locale: :en, token: @player.token)
    unavailable_frame(@player.token)

    get friend_profile_path(locale: :en, token: banned.token)
    unavailable_frame(banned.token)

    @player.update!(visibility: "friends_only")
    get friend_profile_path(locale: :en, token: @player.token)
    assert_response :success
  end

  test "a visitor is sent to the landing" do
    get friend_profile_path(locale: :fr, token: @friend.token)

    assert_redirected_to home_path(locale: :fr)
  end
end
