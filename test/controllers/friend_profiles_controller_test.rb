require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/library_requests"

class FriendProfilesControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include LibraryRequests

  setup do
    OmniAuth.config.test_mode = true
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    @friend.update_columns(persona_name: "Léa")
    Game::Friendship.create!(low_player_id: [ @player.id, @friend.id ].min, high_player_id: [ @player.id, @friend.id ].max)
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def frame_id(player) = "friend-profile-#{player.token}"

  def unavailable_frame(token)
    assert_response :not_found
    assert_select "turbo-frame#friend-profile-#{token}[target=_top] .friend-profile--unavailable", 1
    assert_select ".friend-profile__showcase, .friend-profile__actions", false
    css_select("turbo-frame").to_html.gsub(token, "TOKEN")
  end

  test "a friend sees the name, the count, three cards highest tier first, the trade action and SIGNALER" do
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
      assert_select ".friend-profile__heading", "Vitrine"
      assert_select ".friend-profile__showcase li .card", 3
      assert_select ".friend-profile__showcase li:nth-child(1) .card--s.card--rarity-legendary"
      assert_select ".friend-profile__showcase li:nth-child(2) .card--rarity-epic"
      assert_select ".friend-profile__showcase li:nth-child(3) .card--rarity-rare"
      assert_select ".friend-profile__actions a.button--primary[href=?]", new_trade_path(locale: :fr, friend: @friend.token), "Proposer un échange"
      assert_select ".friend-profile__actions button.button--link[aria-haspopup=dialog][data-dialog-opener-dialog-value=?]",
        "report-dialog-#{@friend.token}", "SIGNALER"
      assert_select "dialog#report-dialog-#{@friend.token} form[action=?]", brother_report_path(locale: :fr, token: @friend.token) do
        assert_select "input[type=hidden][name=from][value=friends]"
      end
    end
    assert_not_includes response.body, @friend.steam_id
  end

  test "a friend holding nothing shows an empty showcase, in English" do
    publish_sets_draft
    @friend.update_columns(last_seen_at: 1.minute.ago)
    sign_in(@player)

    get friend_profile_path(locale: :en, token: @friend.token)

    assert_response :success
    assert_select ".friend-profile__count", "0 cards collected"
    assert_select ".friend-profile__presence .friends__presence--online", "Online"
    assert_select ".friend-profile__showcase", false
    assert_select ".friend-profile__empty", "No card in the showcase."
    assert_select ".friend-profile__actions a.button--primary[href=?]", new_trade_path(locale: :en, friend: @friend.token), "Propose a trade"
  end

  test "a friends-only friend is shown; a private one is the not-available frame" do
    @friend.update!(visibility: "friends_only")
    sign_in(@player)

    get friend_profile_path(locale: :en, token: @friend.token)
    assert_response :success
    assert_select ".friend-profile__name", "Léa"

    @friend.update!(visibility: "private")
    get friend_profile_path(locale: :en, token: @friend.token)
    unavailable_frame(@friend.token)
    assert_select ".friend-profile__empty", "This profile is not available."
    assert_not_includes response.body, "Léa"
  end

  test "a friends-only player still gets the trade action on a friend's profile" do
    @player.update!(visibility: "friends_only")
    sign_in(@player)

    get friend_profile_path(locale: :fr, token: @friend.token)

    assert_response :success
    assert_select ".friend-profile__actions a.button--primary[href=?]", new_trade_path(locale: :fr, friend: @friend.token), "Proposer un échange"
    assert_select ".trades-closed", 0
  end

  test "a private player still sees a friend's showcase, with the trades-closed line instead of the trade action" do
    @player.update!(visibility: "private")
    sign_in(@player)

    get friend_profile_path(locale: :fr, token: @friend.token)

    assert_response :success
    assert_select ".friend-profile__heading", "Vitrine"
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

  test "a visitor is sent home to sign in" do
    get friend_profile_path(locale: :fr, token: @friend.token)

    assert_redirected_to home_path(locale: :fr)
  end
end
