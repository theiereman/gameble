require "test_helper"
require_relative "../support/game_packs"

# The activity feed (CAP-13, CAP-18; story 6.1): readable signed out, newest
# pulls first, a GET writes nothing (AD-11).
class FeedsControllerTest < ActionDispatch::IntegrationTest
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @player.update!(persona_name: "Hugo")
  end

  def open_epic
    create_pack(@player, cards: [ fixture_tier_ids[3] ] * 5)
    Game::OpenPack.new.call(player: @player).value!
  end

  test "a signed-out visitor reads the pulls of Épique or better" do
    open_epic

    get feed_path(locale: :en)

    assert_response :success
    assert_select "main h1", "Activity feed"
    assert_select ".feed__tab[aria-current]", "All"
    assert_select ".feed__entry", 5
    assert_select ".feed__entry--filler", 0
    assert_select ".feed__sentence strong", text: "Hugo"
    assert_select ".feed__tag--epic", /Epic/
  end

  test "the feed is in French" do
    open_epic

    get feed_path(locale: :fr)

    assert_select "main h1", "Fil d'activité"
    assert_select ".feed__sentence", /Hugo a tiré/
  end

  test "an empty feed says so" do
    get feed_path(locale: :en)

    assert_response :success
    assert_select ".feed__empty", "Nothing here yet."
  end

  test "a hidden player's pull is not shown" do
    open_epic
    @player.update!(visibility: :private)

    get feed_path(locale: :en)

    assert_select ".feed__entry", 0
  end

  test "a GET writes no row" do
    open_epic

    assert_no_difference -> { Game::FeedEntry.count + Rails.configuration.event_store.read.count + Game::Pack.count } do
      get feed_path(locale: :en)
    end
  end

  test "menu 05 and the PLUS row link to the feed" do
    get home_path(locale: :en)
    assert_select "a.menu-item[href=?]", feed_path(locale: :en), /Activity feed/

    get more_path(locale: :en)
    assert_select "a.menu-item--plus[href=?]", feed_path(locale: :en)
  end
end
