require "application_system_test_case"
require_relative "../support/game_packs"

# The activity feed's frame: as wide as the hub on a desktop, signed in and
# out, with one "all" choice above its entries; on a phone, its column with
# no sideways scroll.
class FeedTest < ApplicationSystemTestCase
  include GamePacks

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
    create_pack(@player, cards: [ fixture_tier_ids[3] ] * 5)
    Game::OpenPack.new.call(player: @player).value!
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
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    assert_feed_as_wide_as_the_hub
    assert_one_everything
  end

  test "in French, « Tout » shows once and « Tous » not at all" do
    visit feed_path(locale: :fr)

    assert_selector ".feed__entry", count: 5
    within(".feed") do
      assert_text(/\bTout\b/i, count: 1)
      assert_no_text(/\bTous\b/i)
    end
  end

  test "on a phone, the feed keeps its column with no sideways scroll" do
    resize_to(*PHONE)
    visit feed_path(locale: :en)

    assert_selector ".feed__entry", count: 5
    assert_one_everything
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth"), "the feed should not scroll sideways"
  end

  private
    def assert_feed_as_wide_as_the_hub
      visit home_path(locale: :en)
      assert_selector ".hub"
      hub = width_of(".hub")

      visit feed_path(locale: :en)
      assert_selector ".feed__entry", count: 5
      assert_in_delta hub, width_of(".feed__list"), 1, "the feed's list should span the hub's content width"
    end

    def assert_one_everything
      assert_no_selector ".feed__tab"
      assert_selector ".feed__filter", text: /\AEverything\z/i, count: 1
      assert_selector ".feed__filter[aria-current]", text: /\AEverything\z/i
    end

    def width_of(selector)
      page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().width")
    end
end
