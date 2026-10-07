require "test_helper"
require_relative "../support/game_packs"

# The activity feed (CAP-13, CAP-18; stories 6.1, 6.2): readable signed out,
# newest pulls first, under the type filters, a GET writes nothing (AD-11).
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

  test "the five filters show, the whole feed current" do
    get feed_path(locale: :fr)

    assert_equal %w[Tout Tirages Découvertes Échanges Reposts], css_select(".feed__filters .feed__filter").map { |link| link.text.strip }
    assert_select ".feed__filter[aria-current]", count: 1, text: "Tout"
    assert_select ".feed__filter[href=?]", feed_path(locale: :fr), text: "Tout"
    %w[pulls discoveries trades reposts].each do |filter|
      assert_select ".feed__filter[href=?]", feed_path(locale: :fr, filter:)
    end
  end

  test "each kind of entry has its filter" do
    assert_equal Game::FeedEntry::KINDS, FeedsController::FILTERS.values
  end

  test "pulls shows the pulls under the chosen filter and keeps the tab" do
    open_epic

    get feed_path(locale: :en, filter: "pulls")

    assert_response :success
    assert_select ".feed__filter[aria-current]", "Pulls"
    assert_select ".feed__tab[aria-current]", "All"
    assert_select ".feed__entry", 5
  end

  test "a filter with nothing says so, in French and English" do
    open_epic

    %w[discoveries trades reposts].each do |filter|
      get feed_path(locale: :fr, filter:)
      assert_select ".feed__entry", 0
      assert_select ".feed__empty", "Rien pour l'instant dans ce filtre."
    end

    get feed_path(locale: :en, filter: "trades")
    assert_select ".feed__empty", "Nothing in this filter yet."
  end

  test "an unknown filter is the whole feed" do
    open_epic

    get feed_path(locale: :en, filter: "bogus")

    assert_response :success
    assert_select ".feed__filter[aria-current]", "Everything"
    assert_select ".feed__entry", 5
  end

  test "a private or banned player's pulls are gone under a filter" do
    open_epic
    @player.update!(visibility: :private)

    get feed_path(locale: :en, filter: "pulls")
    assert_select ".feed__entry", 0

    @player.update!(visibility: :public, banned_at: Time.current)
    get feed_path(locale: :en, filter: "pulls")
    assert_select ".feed__entry", 0
    assert_select ".feed__empty", "Nothing in this filter yet."
  end

  test "a filtered GET writes no row" do
    open_epic

    assert_no_difference -> { Game::FeedEntry.count + Rails.configuration.event_store.read.count + Game::Pack.count } do
      get feed_path(locale: :en, filter: "pulls")
    end
  end

  test "menu 05 and the PLUS row link to the feed" do
    get home_path(locale: :en)
    assert_select "a.menu-item[href=?]", feed_path(locale: :en), /Activity feed/

    get more_path(locale: :en)
    assert_select "a.menu-item--plus[href=?]", feed_path(locale: :en)
  end
end
