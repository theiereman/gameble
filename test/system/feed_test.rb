require "application_system_test_case"
require_relative "../support/game_packs"

# The activity feed's frame: as wide as the hub on a desktop, signed in and
# out, the All and Friends tabs above one "all" filter; on a phone, its
# column with no sideways scroll. Friends shows only a player's friends'
# entries, combines with the filters, invites a player without friends to
# add some, and opens the sign-in panel for a visitor.
class FeedTest < ApplicationSystemTestCase
  include GamePacks

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
    open_epic(@player)
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  test "signed out, the feed's list spans the hub's width under one choice of everything" do
    assert_feed_as_wide_as_the_hub
    assert_one_everything
  end

  test "signed in, the feed's list spans the hub's width under one choice of everything" do
    sign_in

    assert_feed_as_wide_as_the_hub
    assert_one_everything
  end

  test "in French, the tabs and the filters each show their own word for all, once" do
    visit feed_path(locale: :fr)

    assert_selector ".feed__entry", count: 5
    within(".feed__tabs") do
      assert_selector ".feed__tab", text: /\ATous\z/i, count: 1
      assert_selector ".feed__tab", text: /\AAmis\z/i, count: 1
      assert_no_text(/\bTout\b/i)
    end
    within(".feed") { assert_text(/\bTout\b/i, count: 1) }
    within(".feed__filters") { assert_no_text(/\bTous\b/i) }
  end

  test "on a phone, the feed keeps its column with no sideways scroll" do
    resize_to(*PHONE)
    visit feed_path(locale: :en)

    assert_selector ".feed__entry", count: 5
    assert_one_everything
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), "the feed should not scroll sideways"
  end

  test "signed in, Friends shows a friend's pull and not a stranger's, and Friends · Pulls keeps both choices" do
    friend = accounts_players(:moderator).tap { it.update!(persona_name: "Sam") }
    stranger = accounts_players(:administrator).tap { it.update!(persona_name: "Léa") }
    Game::Friendship.create!(low_player_id: [ @player.id, friend.id ].min, high_player_id: [ @player.id, friend.id ].max)
    open_epic(friend)
    open_epic(stranger)
    sign_in

    visit feed_path(locale: :en)
    assert_selector ".feed__entry", count: 15
    find(".feed__tab", text: /\AFriends\z/i).click

    assert_selector ".feed__tab[aria-current]", text: /\AFriends\z/i
    assert_selector ".feed__entry", count: 5
    assert_selector ".feed__sentence", text: "Sam", count: 5
    assert_no_selector ".feed__sentence", text: "Léa"

    find(".feed__filter", text: /\APulls\z/i).click
    assert_selector ".feed__filter[aria-current]", text: /\APulls\z/i
    assert_selector ".feed__tab[aria-current]", text: /\AFriends\z/i
    assert_selector ".feed__entry", count: 5
    assert_no_selector ".feed__sentence", text: "Léa"

    find(".feed__tab", text: /\AAll\z/i).click
    assert_selector ".feed__tab[aria-current]", text: /\AAll\z/i
    assert_selector ".feed__filter[aria-current]", text: /\APulls\z/i
    assert_selector ".feed__entry", count: 15
  end

  test "signed in without friends, Friends invites to add some and its button leads to the Friends screen" do
    sign_in

    visit feed_path(locale: :fr)
    find(".feed__tab", text: /\AAmis\z/i).click

    assert_selector ".feed__no-friends", text: "Ajoutez des amis pour suivre leurs tirages."
    assert_no_selector ".feed__entry"
    find(".feed__no-friends a.button", text: /\AAjouter des amis\z/i).click

    assert_current_path friends_path(locale: :fr)
    assert_selector "main h1", text: /\AAmis\z/i
  end

  test "signed out, Friends opens the sign-in panel" do
    visit feed_path(locale: :fr)

    find(".feed__tab", text: /\AAmis\z/i).click

    assert_selector "dialog#sign-in-panel[open]"
    assert_selector ".feed__tab[aria-current]", text: /\ATous\z/i
    find("#sign-in-panel .modal__close").click
    assert_no_selector "dialog#sign-in-panel[open]"
  end

  private
    def open_epic(player)
      create_pack(player, cards: [ fixture_tier_ids[3] ] * 5)
      Game::OpenPack.new.call(player:).value!
    end

    def sign_in
      visit home_path(locale: :en)
      click_steam_sign_in
      assert_signed_in
    end

    def assert_feed_as_wide_as_the_hub
      visit home_path(locale: :en)
      assert_selector ".hub"
      hub = width_of(".hub")

      visit feed_path(locale: :en)
      assert_selector ".feed__entry", count: 5
      assert_in_delta hub, width_of(".feed__list"), 1, "the feed's list should span the hub's content width"
    end

    def assert_one_everything
      assert_selector ".feed__tabs .feed__tab", count: 2
      assert_selector ".feed__tab", text: /\AAll\z/i, count: 1
      assert_selector ".feed__tab", text: /\AFriends\z/i, count: 1
      assert_selector ".feed__tab[aria-current]", text: /\AAll\z/i
      assert_selector ".feed__filter", text: /\AEverything\z/i, count: 1
      assert_selector ".feed__filter[aria-current]", text: /\AEverything\z/i
    end

    def width_of(selector)
      page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().width")
    end
end
