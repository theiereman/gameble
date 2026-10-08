require "test_helper"
require_relative "../support/game_packs"

# The activity feed (CAP-13, CAP-18; stories 6.1, 6.2, 6.7): readable signed
# out, newest pulls and first discoveries first, under the type filters, a
# GET writes nothing (AD-11).
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
    assert_select ".feed__tab", false
    assert_select ".feed__filter[aria-current]", "Everything"
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

  test "a first discovery shows with its gold chip under the whole feed and DÉCOUVERTES, in French and English" do
    common = fixture_tier_ids[0]
    Game::FirstDiscovery.where(card_season_id: common).delete_all
    create_pack(@player, cards: [ common ] * 5)
    Game::OpenPack.new.call(player: @player).value!

    get feed_path(locale: :fr)
    assert_select ".feed__entry", 1
    assert_select ".feed__entry--filler", 0
    assert_select ".feed__sentence .feed__chip", "Première découverte"
    assert_select ".feed__sentence", /trouvée par Hugo pour la première fois dans la communauté/

    get feed_path(locale: :en, filter: "discoveries")
    assert_select ".feed__filter[aria-current]", "Discoveries"
    assert_select ".feed__sentence .feed__chip", "First discovery"
    assert_select ".feed__sentence", /found by Hugo for the first time in the community/

    get feed_path(locale: :en, filter: "pulls")
    assert_select ".feed__entry", 0
  end

  test "a pull carries no discovery chip" do
    open_epic

    get feed_path(locale: :en)

    assert_select ".feed__chip", 0
  end

  def repost(card_season_id)
    Game::Holding.create!(player_id: @player.id, card_season_id:, quantity: 1)
    Game::RepostCard.new.call(player: @player, card_season_id:).value!
  end

  test "a repost reads as a sentence with the REPOST tag and its thumbnail framed in its rarity, in French and English" do
    repost(catalog_card_seasons(:portal_one).id)

    get feed_path(locale: :fr)
    assert_select ".feed__entry", 1
    assert_select ".feed__sentence", "Hugo a reposté Portal."
    assert_select ".feed__tag.feed__tag--repost", "Repost"
    assert_select ".feed__tag--epic", 0
    assert_select ".feed__chip", 0
    assert_select "a.feed__thumb.feed__thumb--framed.feed__thumb--epic[href=?]", card_path(locale: :fr, slug: "portal")

    get feed_path(locale: :en)
    assert_select ".feed__sentence", "Hugo reposted Portal."
    assert_select "[style]", 0
  end

  test "REPOSTS shows only the reposts, each with its tag" do
    open_epic
    repost(catalog_card_seasons(:common_card_one).id)

    get feed_path(locale: :en, filter: "reposts")

    assert_select ".feed__filter[aria-current]", "Reposts"
    assert_select ".feed__entry", 1
    assert_select ".feed__entry .feed__tag--repost", 1
    assert_select ".feed__thumb--common", 1

    get feed_path(locale: :en)
    assert_select ".feed__entry", 6
    assert_select ".feed__entry:first-child .feed__sentence", "Hugo reposted Tin Soldier."
  end

  test "a hidden player's repost is not shown" do
    repost(catalog_card_seasons(:portal_one).id)
    @player.update!(visibility: :private)

    get feed_path(locale: :en, filter: "reposts")

    assert_select ".feed__entry", 0
  end

  test "menu 05 and the PLUS row link to the feed" do
    get home_path(locale: :en)
    assert_select "a.menu-item[href=?]", feed_path(locale: :en), /Activity feed/

    get more_path(locale: :en)
    assert_select "a.menu-item--plus[href=?]", feed_path(locale: :en)
  end
end
