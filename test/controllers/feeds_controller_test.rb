require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/game_trades"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# The activity feed, readable without an account: newest pulls and first
# discoveries first, under the All and Friends tabs (Friends a player's)
# and the type filters; a GET writes nothing. Each test reads it as a
# stranger to every player it shows, unless it signs one of them in.
class FeedsControllerTest < ActionDispatch::IntegrationTest
  include GamePacks
  include GameTrades
  include GameSets
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @player.update!(persona_name: "Hugo")
    sign_in_new_player("76561197960287990")
  end

  def open_epic(player = @player)
    create_pack(player, cards: [ fixture_tier_ids[3] ] * 5)
    Game::OpenPack.new.call(player:).value!
  end

  def befriend(first, second)
    Game::Friendship.create!(low_player_id: [ first.id, second.id ].min, high_player_id: [ first.id, second.id ].max)
  end

  def friends_and_strangers
    @friend = accounts_players(:moderator).tap { it.update!(persona_name: "Sam") }
    @stranger = accounts_players(:administrator).tap { it.update!(persona_name: "Léa") }
    befriend(@player, @friend)
    [ @player, @friend, @stranger ].each { open_epic(it) }
    sign_in(@player)
  end

  def names = css_select(".feed__sentence strong:first-child").map(&:text).uniq.sort

  test "a stranger reads the pulls of Epic or better" do
    open_epic

    get feed_path(locale: :en)

    assert_response :success
    assert_select "main h1", "Activity feed"
    assert_select ".feed__tab[aria-current]", "All"
    assert_select ".feed__filter[aria-current]", "Everything"
    assert_select ".feed__entry:not(.feed__entry--set)", 5
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

  test "each kind of entry but the sets has its filter" do
    assert_equal Game::FeedEntry::KINDS - %w[set], FeedsController::FILTERS.values
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
    assert_select ".feed__entry", 6
    assert_select ".feed__entry--set", 1
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

  test "an entry's time is the instant in UTC, for the browser to show in its own time" do
    travel_to(Time.utc(2026, 10, 14, 23, 30)) { open_epic }

    get feed_path(locale: :fr)

    assert_select ".feed__entry time.feed__time[datetime='2026-10-14T23:30:00Z'][data-controller=local-time][data-local-time-style-value=datetime]",
      text: "2026-10-14 23:30 UTC"
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
    assert_select ".feed__entry", 7
    assert_select ".feed__entry:first-child .feed__sentence", "Hugo reposted Tin Soldier."
  end

  test "a hidden player's repost is not shown" do
    repost(catalog_card_seasons(:portal_one).id)
    @player.update!(visibility: :private)

    get feed_path(locale: :en, filter: "reposts")

    assert_select ".feed__entry", 0
  end

  test "menu 06 and the PLUS row link to the feed" do
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
    assert_select ".feed__entry", 6
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

  test "a visitor reads All with its filters and its live stream, filtered by visibility as anyone's" do
    open_epic
    hidden = accounts_players(:administrator).tap { it.update!(persona_name: "Léa", visibility: :private) }
    open_epic(hidden)
    reset!

    get feed_path(locale: :fr)

    assert_response :success
    assert_select "main h1", "Fil d'activité"
    assert_equal %w[Hugo], names
    assert_select ".feed__tab[aria-current]", "Tous"
    assert_equal %w[live:fr], stream_names
    assert_select "ul#feed-entries"

    get feed_path(locale: :en, filter: "pulls")

    assert_response :success
    assert_select ".feed__filter[aria-current]", "Pulls"
    assert_select ".feed__entry", 5
    assert_equal %w[Hugo], names
  end

  test "a visitor's Friends tab is greyed and disabled; a friends query reads All" do
    open_epic
    reset!

    get feed_path(locale: :fr, tab: "friends", filter: "pulls")

    assert_response :success
    assert_select ".feed__tab[aria-current]", count: 1, text: "Tous"
    assert_select "button.feed__tab.segmented__option[type=button][disabled]", "Amis"
    assert_select "a.feed__tab", count: 1
    assert_select "a[href*='tab=friends']", false
    assert_select "a[href$='/friends']", false
    assert_select ".feed__no-friends", false
    assert_select ".feed__entry", 5
    assert_select ".feed__filter[href=?]", feed_path(locale: :fr, filter: "trades")
  end

  test "a visitor's back leads to the landing, not to PLUS; a player's leads to PLUS" do
    reset!

    get feed_path(locale: :fr)

    assert_select ".top-bar__phone-back", false
    assert_select ".top-bar__start > a.top-bar__bridge[href='/fr']"
    assert_select "a[href='/fr/more']", false

    sign_in(@player)
    get feed_path(locale: :fr)

    assert_select "a.top-bar__phone-back[href='/fr/more']"
    assert_select "a.feed__tab[href=?]", feed_path(locale: :fr, tab: "friends"), text: "Amis"
    assert_select "button.feed__tab", false
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

  # The page's public streams, without the signed-in player's own.
  def stream_names
    css_select("turbo-cable-stream-source:not([channel=PlayerStreamChannel])").map { Turbo::StreamsChannel.verified_stream_name(it["signed-stream-name"]) }
  end

  test "All without a filter listens to the public stream, its list named for new entries, with a polite status line" do
    open_epic

    get feed_path(locale: :fr)

    assert_equal %w[live:fr], stream_names
    assert_select "section.feed[data-controller=feed-announcer][data-feed-announcer-limit-value=?]", Game::FeedEntries::LIMIT.to_s
    assert_select "section.feed[data-controller=feed-announcer]" do |section|
      templates = JSON.parse(section.sole["data-feed-announcer-templates-value"])
      assert_equal "3 nouvelles entrées dans le fil.", templates["other"].sub("%{count}", "3")
      assert_equal "1 nouvelle entrée dans le fil.", templates["one"]
      assert templates["zero"]
    end
    assert_select "ul#feed-entries.feed__list[data-feed-announcer-target=list] > li.feed__entry", 6
    assert_select ".feed p.visually-hidden[role=status][data-feed-announcer-target=status]", text: ""
  end

  test "an empty All keeps its live list for the first entry, beside the empty line" do
    get feed_path(locale: :en)

    assert_select "ul#feed-entries", 1
    assert_select "ul#feed-entries > li", 0
    assert_select ".feed__empty", "Nothing here yet."
    assert_equal %w[live:en], stream_names
  end

  test "a filtered view and the Friends tab are read at render: no stream, no live list, no status line" do
    friends_and_strangers

    { feed_path(locale: :en, filter: "pulls") => 15, feed_path(locale: :en, tab: "friends") => 6 }.each do |path, entries|
      get path
      assert_select ".feed__entry", entries
      assert_select "#feed-entries, .feed [role=status], [data-controller=feed-announcer]", 0
      assert_equal [], stream_names, path
    end
  end

  def add_repost(player)
    card_season_id = catalog_card_seasons(:portal_one).id
    Game::Holding.find_or_create_by!(player_id: player.id, card_season_id:) { it.quantity = 1 }
    Game::RepostCard.new.call(player:, card_season_id:).value!
  end

  def trade_with(partner)
    conclude_trade(@player, partner, offer: { catalog_card_seasons(:portal_one).id => 1 },
      request: { catalog_card_seasons(:rare_card_one).id => 1 })
  end

  test "a trade reads as both players trading their best cards, both thumbnails framed, with the Trade tag, under All and Trades" do
    open_epic
    trade_with(accounts_players(:moderator).tap { it.update!(persona_name: "Sam") })

    get feed_path(locale: :fr, filter: "trades")
    assert_select ".feed__filter[aria-current]", "Échanges"
    assert_select ".feed__entry", 1
    assert_select ".feed__sentence", "Hugo et Sam ont échangé Portal contre Profondeurs bleues"
    assert_select ".feed__tag.feed__tag--trade", /Échange/
    assert_select ".feed__tag.feed__tag--trade .pixel-icon"
    assert_select ".feed__thumbs a.feed__thumb.feed__thumb--framed.feed__thumb--epic[href=?]", card_path(locale: :fr, slug: "portal")
    assert_select ".feed__thumbs a.feed__thumb.feed__thumb--framed.feed__thumb--rare", 1
    assert_select ".feed__tag--epic", 0

    get feed_path(locale: :en)
    assert_select ".feed__entry", 8, "five pulls, the trade, and each player's completion of the Valve set"
    assert_select ".feed__entry:first-child .feed__sentence", "Hugo and Sam traded Portal for Blue Depths"
    assert_select ".feed__entry:first-child .feed__tag--trade", /Trade/
    assert_select "[style]", 0
  end

  test "a trade with a hidden player is not shown to a stranger" do
    sam = accounts_players(:moderator)
    trade_with(sam)
    sam.update!(visibility: :friends_only)

    get feed_path(locale: :en, filter: "trades")
    assert_select ".feed__entry", 0

    get feed_path(locale: :en)
    assert_select ".feed__entry", 0
  end

  test "Friends shows a trade with a friend on either side, under Trades too" do
    friend = accounts_players(:moderator).tap { it.update!(persona_name: "Sam") }
    viewer = accounts_players(:administrator)
    befriend(viewer, friend)
    friend.update!(visibility: :friends_only)
    trade_with(friend)
    sign_in(viewer)

    get feed_path(locale: :en, tab: "friends", filter: "trades")
    assert_select ".feed__entry", 1
    assert_select ".feed__sentence", "Hugo and Sam traded Portal for Blue Depths"

    get feed_path(locale: :en, tab: "friends")
    assert_equal [ "Hugo and Sam traded Portal for Blue Depths", "Sam completes the Valve set." ],
      css_select(".feed__entry .feed__sentence").map(&:text)
  end

  def reach_roguelike_silver(player = @player)
    common, uncommon, rare, = fixture_tier_ids
    insert_set([ common, uncommon, rare, *unheld_cards(2) ], { silver: 2, gold: 3, complete: 5 })
    Game::Holding.create!(player_id: player.id, card_season_id: uncommon, quantity: 1)
    create_pack(player, cards: [ common ] * 5)
    Game::OpenPack.new.call(player:).value!
  end

  test "a stranger reads a set reached as one line naming the player, the set and the tier, with no thumbnail" do
    reach_roguelike_silver

    get feed_path(locale: :en)

    assert_select ".feed__entry.feed__entry--set", 1 do
      assert_select ".feed__sentence", "Hugo reaches silver in the Roguelike set."
      assert_select ".feed__tag.feed__tier--silver", "Silver"
      assert_select ".feed__tier-notches i", 2
      assert_select ".feed__thumb, .card", 0
    end
    assert_select "[style]", 0

    get feed_path(locale: :fr)
    assert_select ".feed__entry--set .feed__sentence", "Hugo atteint l'argent du set Roguelike."
    assert_select ".feed__entry--set .feed__tag", "Argent"
  end

  test "a rank reached reads its name behind its rank's mark, without notches" do
    common, uncommon, rare, legendary = fixture_tier_ids.values_at(0, 1, 2, 4)
    insert_set([ common, uncommon, rare, legendary, fixture_tier_ids[3] ], Catalog::TierTable.tiers(5))
    [ uncommon, rare ].each { Game::Holding.create!(player_id: @player.id, card_season_id: it, quantity: 1) }
    create_pack(@player, cards: [ common ] * 5)
    Game::OpenPack.new.call(player: @player).value!

    get feed_path(locale: :en)

    assert_select ".feed__entry.feed__entry--set", 1 do
      assert_select ".feed__sentence", "Hugo reaches the Master tier in the Roguelike set."
      assert_select ".feed__tag.feed__tier--master", "Master"
      assert_select ".feed__tier-mark > svg.pixel-icon.rank-mark.rank-mark--master.rank-mark--fine[aria-hidden=true]", 1
      assert_select ".feed__tier-notches", 0
    end

    get feed_path(locale: :fr)
    assert_select ".feed__entry--set .feed__sentence", "Hugo atteint le palier Maître du set Roguelike."
    assert_select ".feed__entry--set .feed__tag", "Maître"
  end

  test "a private player's set line is not shown, and no filter is for sets" do
    reach_roguelike_silver
    @player.update!(visibility: :private)

    get feed_path(locale: :en)
    assert_select ".feed__entry", 0

    @player.update!(visibility: :public)
    %w[pulls discoveries trades reposts].each do |filter|
      get feed_path(locale: :en, filter:)
      assert_select ".feed__entry--set", 0
    end
  end
end
