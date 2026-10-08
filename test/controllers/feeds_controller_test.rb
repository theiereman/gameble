require "test_helper"
require_relative "../support/game_packs"

# The activity feed: readable signed out, newest pulls and first discoveries
# first, under the All and Friends tabs and the type filters; a GET writes
# nothing.
class FeedsControllerTest < ActionDispatch::IntegrationTest
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @player.update!(persona_name: "Hugo")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def open_epic(player = @player)
    create_pack(player, cards: [ fixture_tier_ids[3] ] * 5)
    Game::OpenPack.new.call(player:).value!
  end

  def sign_in(player)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    post "/auth/steam", params: { origin: "/en" }
    follow_redirect!
  end

  def befriend(first, second)
    Game::Friendship.create!(low_player_id: [ first.id, second.id ].min, high_player_id: [ first.id, second.id ].max)
  end

  def friends_and_strangers(signed_in: true)
    @friend = accounts_players(:moderator).tap { it.update!(persona_name: "Sam") }
    @stranger = accounts_players(:administrator).tap { it.update!(persona_name: "Léa") }
    befriend(@player, @friend)
    [ @player, @friend, @stranger ].each { open_epic(it) }
    sign_in(@player) if signed_in
  end

  def names = css_select(".feed__sentence strong:first-child").map(&:text).uniq.sort

  test "a signed-out visitor reads the pulls of Epic or better" do
    open_epic

    get feed_path(locale: :en)

    assert_response :success
    assert_select "main h1", "Activity feed"
    assert_select ".feed__tab[aria-current]", "All"
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

  test "a first discovery shows with its gold chip under the whole feed and Discoveries, in French and English" do
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

  test "Reposts shows only the reposts, each with its tag" do
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

  test "All shows everyone's entries, current, beside Friends" do
    friends_and_strangers

    get feed_path(locale: :en)

    assert_equal %w[All Friends], css_select(".feed__tabs .feed__tab").map { |tab| tab.text.strip }
    assert_select ".feed__tabs[aria-label=?]", "Whose events"
    assert_select ".feed__tab[aria-current]", count: 1, text: "All"
    assert_select "a.feed__tab[href=?]", feed_path(locale: :en, tab: "friends"), text: "Friends"
    assert_equal %w[Hugo Léa Sam], names
  end

  test "Friends shows only the friends' entries, not the player's own nor a stranger's" do
    friends_and_strangers

    get feed_path(locale: :en, tab: "friends")

    assert_response :success
    assert_select ".feed__tab[aria-current]", count: 1, text: "Friends"
    assert_select ".feed__entry", 5
    assert_equal %w[Sam], names
    assert_select ".feed__no-friends", 0
  end

  test "Friends · Pulls shows the friends' pulls, each row keeping the other's choice" do
    friends_and_strangers
    add_repost(@friend)

    get feed_path(locale: :fr, tab: "friends", filter: "pulls")

    assert_select ".feed__tab[aria-current]", "Amis"
    assert_select ".feed__filter[aria-current]", "Tirages"
    assert_select ".feed__entry", 5
    assert_select ".feed__tag--repost", 0
    assert_equal %w[Sam], names
    assert_select "a.feed__tab[href=?]", feed_path(locale: :fr, filter: "pulls"), text: "Tous"
    assert_select "a.feed__tab[href=?]", feed_path(locale: :fr, tab: "friends", filter: "pulls"), text: "Amis"
    assert_select "a.feed__filter[href=?]", feed_path(locale: :fr, tab: "friends"), text: "Tout"
    %w[pulls discoveries trades reposts].each do |filter|
      assert_select "a.feed__filter[href=?]", feed_path(locale: :fr, tab: "friends", filter:)
    end

    get feed_path(locale: :fr, tab: "friends", filter: "reposts")
    assert_select ".feed__entry", 1
    assert_select ".feed__sentence", "Sam a reposté Portal."
  end

  test "Friends without a friend invites to add some, in French and English" do
    open_epic
    sign_in(@player)

    get feed_path(locale: :fr, tab: "friends")

    assert_response :success
    assert_select ".feed__entry", 0
    assert_select ".feed__empty", 0
    assert_select ".feed__no-friends" do
      assert_select "p", "Ajoutez des amis pour suivre leurs tirages."
      assert_select "a.button.button--primary[href=?]", friends_path(locale: :fr), "Ajouter des amis"
    end

    get feed_path(locale: :en, tab: "friends", filter: "trades")
    assert_select ".feed__no-friends p", "Add friends to follow their pulls."
    assert_select ".feed__no-friends a[href=?]", friends_path(locale: :en), "Add friends"
  end

  test "Friends with friends but nothing under the filter says the filter's empty line" do
    friends_and_strangers

    get feed_path(locale: :en, tab: "friends", filter: "trades")

    assert_select ".feed__entry", 0
    assert_select ".feed__no-friends", 0
    assert_select ".feed__empty", "Nothing in this filter yet."
  end

  test "a private friend's entries are absent from the Friends tab" do
    friends_and_strangers
    @friend.update!(visibility: :private)

    get feed_path(locale: :en, tab: "friends")

    assert_select ".feed__entry", 0
    assert_select ".feed__empty", "Nothing here yet."
  end

  test "signed out, Friends opens the sign-in panel and ?tab=friends reads All" do
    friends_and_strangers(signed_in: false)

    get feed_path(locale: :en, tab: "friends", filter: "pulls")

    assert_response :success
    assert_select ".feed__tab[aria-current]", count: 1, text: "All"
    assert_select "a.feed__tab[href=?]", feed_path(locale: :en, filter: "pulls"), text: "All"
    assert_select "button.feed__tab[type=button][aria-haspopup=dialog][data-dialog-opener-dialog-value=sign-in-panel]", "Friends"
    assert_select "a.feed__tab", 1
    assert_select "a.feed__filter[href=?]", feed_path(locale: :en)
    assert_equal %w[Hugo Léa Sam], names
  end

  test "an unknown tab is All" do
    friends_and_strangers

    get feed_path(locale: :en, tab: "zzz")

    assert_select ".feed__tab[aria-current]", "All"
    assert_equal %w[Hugo Léa Sam], names
  end

  test "a Friends GET writes no row" do
    friends_and_strangers

    assert_no_difference -> { Game::FeedEntry.count + Rails.configuration.event_store.read.count + Game::Pack.count + Game::Friendship.count } do
      get feed_path(locale: :en, tab: "friends", filter: "pulls")
    end
  end

  def add_repost(player)
    card_season_id = catalog_card_seasons(:portal_one).id
    Game::Holding.find_or_create_by!(player_id: player.id, card_season_id:) { it.quantity = 1 }
    Game::RepostCard.new.call(player:, card_season_id:).value!
  end
end
