require "test_helper"
require_relative "../support/steam_sign_in"

# While the duels are switched off, nothing of them shows and none of their pages exists.
class DuelsSwitchTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    Game::SetFeatureFlag.new.call(player: accounts_players(:administrator), key: "duels", enabled: false).value!
    sign_in(@player)
  end

  test "the phone tab bar has four tabs and the hub menu has no Duels entry, its other numbers closing the gap" do
    get home_path(locale: :en)

    assert_equal %w[Bridge Capsule Sets Commerce], css_select(".tab-bar__label").map(&:text)
    assert_select ".hub-menu a[href='#{duels_path(locale: :en)}']", 0
    assert_select ".hub-menu a.menu-item[aria-keyshortcuts='4'][href='#{feed_path(locale: :en)}'] .menu-item__number", "04"
    assert_select ".hub-menu a.menu-item[aria-keyshortcuts='5'][href='#{achievements_path(locale: :en)}'] .menu-item__number", "05"
    assert_select ".hub-menu button.menu-item[aria-keyshortcuts='6'] .menu-item__number", "06"
  end

  test "every duel page answers not found" do
    get duels_path(locale: :en)
    assert_response :not_found
    get new_deck_path(locale: :en)
    assert_response :not_found
    post duel_practice_path(locale: :en)
    assert_response :not_found
    get new_feedback_path(locale: :en)
    assert_response :not_found
  end

  test "the page of the rules, a friend's profile and a card carry nothing about the duels" do
    get how_it_works_path(locale: :en)
    assert_select "#how-it-works-duels", 0

    get brother_path(locale: :en, token: accounts_players(:moderator).token)
    assert_select "a[href='#{duels_path(locale: :en)}']", 0
  end

  test "the weekly feed post is not written" do
    assert_no_difference -> { Game::FeedEntry.where(kind: "duel_stats").count } do
      Game::Handlers::DuelStatsFeed.call(Game::DuelStatsComputed.new(data: { reason: "weekly" }))
    end
  end
end
