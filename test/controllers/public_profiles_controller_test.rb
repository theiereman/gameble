require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

class PublicProfilesControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include GameSets
  include LibraryRequests
  include SteamSignIn

  setup do
    @owner = accounts_players(:player)
    @owner.update_columns(persona_name: "Gabe the Brave")
  end

  def album_count = css_select(".set-album__count").sole.text.squish

  # The figures of a block as [ label, value ].
  def figures(scope) = css_select("#{scope} .profile-figure").map { [ it.at_css("dt").text.squish, it.at_css("dd").text.squish ] }
  def keys = figures(".profile-band__keys")
  def key(label) = keys.to_h.fetch(label)

  # The started sets' tiles as [ name, "owned/total", href ].
  def set_rows
    css_select(".profile-sets.set-tiles > li > a.set-tile").map { [ it.at_css(".set-tile__name").text, it.at_css(".set-tile__count").text, it["href"] ] }
  end

  def card_total(season) = Catalog::CardSeason.where(season_id: season.id).where.not(rarity: nil).count

  def unlock(key, at) = Game::AchievementUnlock.create!(player_id: @owner.id, achievement: key, unlocked_at: at)

  def written_statements(&request)
    statements = []
    record = ->(*, payload) { statements << payload[:sql] if payload[:sql].match?(/\A\s*(INSERT|UPDATE|DELETE)\b/i) }
    ActiveSupport::Notifications.subscribed(record, "sql.active_record", &request)
    statements
  end

  # All of Pirates (complete), so half of Horror; two of RPG, both also
  # Roguelike; and one UFO.
  def hold_started_sets(season)
    set_members(season, "pirates").each { hold(@owner, it, 1) }
    set_members(season, "rpg").first(2).each { hold(@owner, it, 1) }
    hold(@owner, set_members(season, "ufos").first, 1)
  end

  def open_packs(season, count)
    card = set_members(season, "rpg").first
    count.times do
      Game::Pack.create!(player_id: @owner.id, kind: :regular, season_id: season.id, card_season_ids: Array.new(Game::Pack::SIZE, card),
        available_at: 1.hour.ago, opened_at: 1.hour.ago)
    end
  end

  def conclude_trade_with(partner)
    low, high = [ @owner.id, partner.id ].minmax
    Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: partner.id, recipient_id: @owner.id, status: "accepted",
      proposed_at: 1.day.ago, expires_at: 6.days.from_now)
  end

  test "a visitor sees the identity band, the stats, the latest achievements and the started sets, complete first then by share, and the GET writes nothing" do
    season = publish_sets_draft
    hold_started_sets(season)
    @owner.update_columns(created_at: Time.zone.local(2026, 3, 14, 12))
    { "first_booster" => 5, "first_epic" => 4, "first_complete_set" => 1, "boosters_10" => 2, "first_trade" => 3 }.each { |key, days| unlock(key, days.days.ago) }
    open_packs(season, 2)
    Game::FirstDiscovery.create!(card_season_id: set_members(season, "pirates").first, player_id: @owner.id, discovered_at: Time.current)
    conclude_trade_with(accounts_players(:moderator))

    written = written_statements { get brother_path(locale: :en, token: @owner.token) }

    assert_response :success
    assert_empty written
    assert_select "title", "Gabe the Brave"
    assert_select "h1", 1
    assert_select "h1#profile-heading", "Gabe the Brave"
    assert_select ".top-bar__title", "Gabe the Brave"
    assert_select "meta[name=robots][content=noindex]"
    assert_select "header.profile-band.panel--brackets svg.profile-band__avatar[aria-hidden=true]"
    assert_select ".profile-band__since", "Member since March 2026"
    assert_select ".profile-band__meta button.button--link.button--small[type=button][disabled]", "REPORT"
    assert_select ".profile-band__identity > button.button--secondary.button--small[type=button][disabled][aria-label=?]", "Trade with Gabe the Brave",
      text: "TRADE"
    assert_select ".profile-band [aria-haspopup], .profile-band a", false
    assert_equal [ [ "Cards", "11/#{card_total(season)}" ], [ "Complete sets", "1" ], [ "Achievements", "5/10" ] ], keys

    assert_select "section.profile-stats[aria-label=Statistics]"
    rarities = figures(".profile-stats__grid--rarities")
    assert_equal [ "Common", "Uncommon", "Rare", "Epic", "Legendary" ], rarities.map(&:first)
    assert_equal 11, rarities.sum { it.last.to_i }
    assert_select ".profile-stats__grid--rarities .profile-figure--rarity-5 svg.profile-figure__icon"
    assert_equal [ [ "Capsules opened", "2" ], [ "First discoveries", "1" ], [ "Trades concluded", "1" ] ],
      figures(".profile-stats__grid:not(.profile-stats__grid--rarities)")

    assert_equal [ "Achievements", "Sets" ], css_select("h2").map(&:text)
    assert_select "#profile-achievements-heading ~ .achievements__head .visually-hidden", "5 achievements earned out of 10"
    assert_select "#profile-achievements-heading ~ .achievements__head .achievements__segment--lit", 5
    assert_select ".profile-section__label", "Latest earned"
    assert_equal [ "First complete set", "10 capsules", "First trade", "First Epic" ],
      css_select(".profile-achievements .achievement__name").map(&:text)
    assert_select ".profile-achievements .achievement--locked, .profile-achievements .achievement__bar", false

    assert_select ".profile-section__aside", "5 sets started"
    rows = set_rows
    assert_equal [ "8/8", "8/16", "1/7", "2/44", "2/127" ], rows.map(&:second)
    assert_equal [ "Pirates", "8/8", "/en/brothers/#{@owner.token}/library/theme/pirates" ], rows.first
    assert_equal [ "Horror", "8/16", "/en/brothers/#{@owner.token}/library/theme/horror" ], rows.second
    assert_select ".profile-sets .set-chip--rank.tier-tone--complete", "Complete"
    assert_select ".profile-sets .set-tile--closest", 1
    assert_select ".profile-sets .set-tile__face--verso .set-tile__cta", 5
    assert_select ".profile-sets .set-tile__card .card", minimum: 1
    assert_select ".profile-sets .set-tile__last", false

    assert_select ".set-search, .set-entry", false
    assert_select "[style]", false
  end

  test "the owner's own profile has no SIGNALER" do
    publish_sets_draft
    sign_in(@owner)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select ".profile-band button", false
    assert_select "#report-dialog", false
  end

  test "fewer than four achievements earned: as many tiles" do
    publish_sets_draft
    unlock("first_booster", 2.days.ago)
    unlock("first_epic", 1.day.ago)

    get brother_path(locale: :en, token: @owner.token)

    assert_equal [ "First Epic", "First capsule" ], css_select(".profile-achievements .achievement__name").map(&:text)
  end

  test "the owner's figures, never the viewer's" do
    season = publish_sets_draft
    set_members(season, "horror").first(2).each { |id| hold(@owner, id, 1) }
    viewer = accounts_players(:moderator)
    set_members(season, "rpg").first(5).each { |id| hold(viewer, id, 1) }
    sign_in(viewer)

    get brother_path(locale: :en, token: @owner.token)

    assert_equal "2/#{card_total(season)}", key("Cards")
    assert_not_includes set_rows.map(&:first), "RPG"
    assert_includes set_rows, [ "Horror", "2/16", "/en/brothers/#{@owner.token}/library/theme/horror" ]

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg")
    owned = (set_members(season, "rpg") & set_members(season, "horror").first(2)).size
    assert_select ".set-album__grid .card:not(.card--not-owned)", owned
    assert_select ".set-album__grid .card.card--not-owned", set_members(season, "rpg").size - owned
  end

  test "an owner with more started sets than the profile shows: the most complete ones, under a count of them all" do
    season = publish_sets_draft
    hold_started_sets(season)
    held = Game::Holding.where(player_id: @owner.id).pluck(:card_season_id)
    unheld = Catalog::CardSeason.where(season_id: season.id).where.not(id: held).order(:id).ids
    17.times { insert_set([ held.first, *unheld.first(2) ], {}, kind: "franchise", key: "third-#{it}", params: { "franchise" => "Third #{it}" }, season:) }

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select ".profile-section__aside", "22 sets started"
    assert_equal [ "8/8", "8/16", *[ "1/3" ] * 4 ], set_rows.map(&:second)
  end

  test "a new owner: zeros, an unlit gauge with no latest tiles, the zero sets line and no rows" do
    season = publish_sets_draft

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_equal [ [ "Cards", "0/#{card_total(season)}" ], [ "Complete sets", "0" ], [ "Achievements", "0/10" ] ], keys
    assert_equal [ 0 ] * 5, figures(".profile-stats__grid--rarities").map { it.last.to_i }
    assert_select ".achievements__segment", 10
    assert_select ".achievements__segment--lit", false
    assert_select ".profile-section__label, .profile-achievements", false
    assert_select ".profile-section__aside", "0 sets started"
    assert_select ".profile-sets", false
  end

  test "with no season published the band shows zero cards and the no-season line stands for the rest" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select ".profile__no-season", "No season of cards is published yet."
    assert_equal [ [ "Cards", "0" ], [ "Complete sets", "0" ], [ "Achievements", "0/10" ] ], keys
    assert_select ".profile-stats, .profile-section", false
  end

  test "a signed-out visitor opens an owner's album: the owner's faces and copies, the cards they lack not owned, read-only, under the set and the owner's names" do
    season = publish_sets_draft
    members = set_members(season, "horror")
    [ 0, 3, 7, 12, 14, 15 ].each { hold(@owner, members[it], it == 3 ? 2 : 1, gained_at: 1.minute.ago) }

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "horror")

    assert_response :success
    assert_select "title", "Horror · Gabe the Brave · Gameble"
    assert_select "meta[name=robots][content=noindex]"
    assert_select "h1", 1
    assert_select "h1#set-album-heading[tabindex='-1']", "Horror · Gabe the Brave"
    assert_equal "6/16", album_count
    assert_equal "6 cards out of 16, expert tier", css_select("progress.set-album__bar").sole["aria-valuetext"]
    assert_select ".set-album__gauge, .set-album__kind", false
    assert_select "ol.set-album__grid.collection-grid--fill .card.card--grid", 16
    assert_select ".card--m", false
    assert_equal [ "x2" ], css_select(".collection-slot__copies").map(&:text)
    assert_equal members.each_index.map { [ 0, 3, 7, 12, 14, 15 ].exclude?(it) },
      css_select(".set-album__grid > li").map { it.at_css(".card--not-owned").present? }
    assert_select ".set-album__grid a.card-link[aria-label$=', not owned'] .card--not-owned > .card__lock", 10
    assert_select ".collection-slot__new", false
    assert_select ".top-bar__end .collection-status, .top-bar__title", false
    assert_select ".profile-band, .collection-kind, .collection-sets", false
    assert_select "[style]", false
    slugs = Catalog::CardSeason.where(id: members).includes(:card).index_by(&:id).transform_values { it.card.slug }
    assert_equal members.map { "/en/cards/#{slugs.fetch(it)}/seasons/#{season.number}?brother=#{@owner.token}&set_key=horror&set_kind=theme" },
      css_select(".set-album__grid > li > a.card-link").map { it["href"] }
  end

  test "a visitor filters an owner's album by the owner's holdings, never the viewer's, under the same header" do
    season = publish_sets_draft
    members = set_members(season, "horror")
    held = [ 0, 3, 7, 12, 14, 15 ]
    held.each { hold(@owner, members[it], 1) }
    viewer = accounts_players(:moderator)
    members.first(10).each { hold(viewer, it, 1) }
    path = brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "horror")

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "horror", state: [ "missing" ])

    assert_response :success
    assert_select "form.filters[action=?] [data-group=state] .filter-chip__box[value=missing][checked]", path
    assert_select ".filters__clear[href=?]", path
    assert_equal members.each_index.reject { held.include?(it) }.size, css_select(".set-album__grid .card--not-owned").size
    assert_select ".set-album__grid .card:not(.card--not-owned)", false
    assert_equal "6/16", album_count

    sign_in(viewer)
    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "horror", state: [ "owned" ])
    assert_select ".set-album__grid .card:not(.card--not-owned)", 6
    assert_select ".set-album__grid .card--not-owned", false
    assert_equal "6/16", album_count
  end

  test "a visitor narrows an owner's album by rarity and finds a game of it by its name, under the same header" do
    season = publish_sets_draft
    members = set_members(season, "horror")
    Catalog::CardSeason.where(id: members).update_all(rarity: Catalog::Rarity::TIERS.key(:common))
    Catalog::CardSeason.where(id: members.values_at(2, 5)).update_all(rarity: Catalog::Rarity::TIERS.key(:rare))
    hold(@owner, members[5], 1)
    Catalog::CardText.where(card_id: Catalog::CardSeason.find(members[7]).card_id, locale: "en").update_all(title: "Élan Vital")

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "horror", rarity: [ "rare" ])

    assert_response :success
    assert_select "[data-group=rarity] .filter-chip__box[value=rare][checked]"
    assert_equal [ true, false ], css_select(".set-album__grid > li").map { it.at_css(".card--not-owned").present? }
    assert_equal "1/16", album_count

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "horror", q: "ELAN")

    assert_select "#collection-search[value=ELAN]"
    assert_equal [ "Élan Vital" ], css_select(".set-album__grid .card__title").map { it.text.squish }
    assert_equal "1/16", album_count
  end

  test "an owner's album shows their earlier editions and their copies of every edition" do
    season = publish_sets_draft
    members = set_members(season, "pirates")
    older = Catalog::CardSeason.find(members[1])
    earlier = Catalog::CardSeason.insert_all!([ { card_id: older.card_id, season_id: catalog_seasons(:one).id, prestige_score: 0.5, rating: 80.0,
      rarity: Catalog::Rarity::TIERS.key(:legendary), number: 900 } ], returning: :id).rows.flatten.sole
    hold(@owner, earlier, 1)
    hold(@owner, members[1], 2)

    get brother_set_path(locale: :fr, token: @owner.token, kind: "theme", key: "pirates")

    assert_equal "1/8", album_count
    slot = css_select(".set-album__grid > li")[1]
    assert_equal "/fr/cards/#{older.card.slug}/seasons/#{season.number}?brother=#{@owner.token}&set_key=pirates&set_kind=theme", slot.at_css("a.card-link")["href"]
    assert_equal "x3", slot.at_css(".collection-slot__copies").text
    assert_equal "1 carte sur 8", css_select("progress.set-album__bar").sole["aria-valuetext"]
  end

  test "an owner's album costs eight queries for a visitor, filtered or not, a signed-in viewer's six more" do
    season = publish_sets_draft
    hold(@owner, set_members(season, "rpg").first, 1)

    # Owner by token, published season; the album: its set, members and
    # tiers, the owner's editions, the page's card views; the themes' names.
    assert_request_queries(8) { get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg") }
    assert_response :success
    assert_request_queries(8) { get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg", rarity: [ "common" ], q: "seed") }
    assert_response :success

    sign_in(accounts_players(:moderator))
    # The same, the viewer's lookup, the top bar's four and the trades
    # waiting.
    assert_request_queries(14) { get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg") }
    assert_response :success
  end

  test "a wrong kind, an unknown key or a key of another kind is not found under a profile" do
    publish_sets_draft

    get "/en/brothers/#{@owner.token}/library/nope/rpg"
    assert_response :not_found

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "action")
    assert_response :not_found

    get brother_set_path(locale: :en, token: @owner.token, kind: "studio", key: "rpg")
    assert_response :not_found
  end

  test "with no season published no set is found under a profile" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg")
    assert_response :not_found
  end

  test "an unknown token shows the unavailable page with a 404, after one lookup" do
    publish_sets_draft

    assert_request_queries(1) { get brother_path(locale: :en, token: "A" * 24) }

    assert_response :not_found
    assert_select "title", "Profile not available"
    assert_select "h1", "Profile not available"
    assert_select "meta[name=robots][content=noindex]"
    assert_select ".collection, .collection-sets", false

    get brother_set_path(locale: :en, token: "A" * 24, kind: "theme", key: "rpg")
    assert_response :not_found
    assert_select "h1", "Profile not available"
  end

  test "a malformed token is a routing 404, with no query" do
    assert_request_queries(0) { get "/en/brothers/abcde" }
    assert_response :not_found

    # 0, O, I and l are not base58.
    get "/en/brothers/#{"0" * 24}"
    assert_response :not_found
    get "/en/brothers/#{"A" * 25}"
    assert_response :not_found
  end

  test "a visitor opens an owner's whole collection: the owner's holdings, the cards they lack faded, read-only" do
    season = publish_sets_draft
    held = Catalog::CardSeason.where(season_id: season.id).order(:number, :id).first(3).map(&:id)
    hold(@owner, held[0], 2, gained_at: 1.minute.ago)
    hold(@owner, held[1], 1, gained_at: 1.minute.ago)

    statements = written_statements { get brother_collection_path(locale: :en, token: @owner.token) }

    assert_response :success
    assert_empty statements
    assert_select "meta[name=robots][content=noindex]"
    assert_select "title", "Collection · Gabe the Brave · Gameble"
    assert_select "h1", "Collection · Gabe the Brave"
    assert_select ".collection:not(.collection--visitor) .collection__aside"
    assert_select ".collection-slot .card--not-owned", 58
    assert_equal [ "x1", "x2" ], css_select(".collection-slot__copies").map(&:text).sort
    assert_select ".collection-slot__new", false
    assert_select "[data-controller~=collection-seen]", false
    assert_select "[data-controller~=next-page]", false
    assert_select "turbo-frame#collection-results[data-action]", false
    assert_select ".top-bar__end .collection-status", false
    assert_select "main form:not([method=get])", false
    assert_select "form[role=search][action=?]", brother_collection_path(locale: :en, token: @owner.token)
    assert_select "a.filters__clear[href=?]", brother_collection_path(locale: :en, token: @owner.token)
    assert_select "ol#collection-slots[data-controller=grid-keys]", 1
    assert_select "[style]", false
    assert_select "input[name='state[]'][value=new]", 0
    assert_select "input[name='state[]'][value=owned]", 1
  end

  test "the grid follows the owner's holdings, never the signed-in viewer's" do
    season = publish_sets_draft
    cards = Catalog::CardSeason.where(season_id: season.id).order(:number, :id).first(2).map(&:id)
    viewer = accounts_players(:moderator)
    hold(viewer, cards[0], 3)
    hold(@owner, cards[1], 1)
    sign_in(viewer)

    get brother_collection_path(locale: :en, token: @owner.token, state: %w[owned])

    assert_equal 1, css_select(".collection-slot").size
    assert_equal [ "x1" ], css_select(".collection-slot__copies").map(&:text)
  end

  test "the states owned, missing and duplicates narrow the owner's grid; new is ignored" do
    season = publish_sets_draft
    cards = Catalog::CardSeason.where(season_id: season.id).order(:number, :id).first(3).map(&:id)
    hold(@owner, cards[0], 2, gained_at: 1.minute.ago)
    hold(@owner, cards[1], 1, gained_at: 1.minute.ago)

    get brother_collection_path(locale: :en, token: @owner.token, state: %w[duplicates])
    assert_equal 1, css_select(".collection-slot").size

    get brother_collection_path(locale: :en, token: @owner.token, state: %w[owned])
    assert_equal 2, css_select(".collection-slot").size

    get brother_collection_path(locale: :en, token: @owner.token, state: %w[missing])
    assert_select ".collection-slot .card--not-owned", 60

    get brother_collection_path(locale: :en, token: @owner.token, state: %w[new])
    assert_response :success
    assert_select ".collection-slot", 60
    assert_select ".collection-slot__new", false
    assert_select "[data-controller~=collection-seen]", false
  end

  test "the search and the pages work as in the player's own grid" do
    publish_sets_draft

    get brother_collection_path(locale: :en, token: @owner.token, q: "Seed 1", genre: %w[roguelike])
    assert_response :success

    get brother_collection_path(locale: :en, token: @owner.token, q: "Seed 1")
    assert_response :success
    assert_operator css_select(".collection-slot").size, :>, 0
    assert_select "a.filters__clear:not([hidden])"

    get brother_collection_path(locale: :en, token: @owner.token, page: 2)
    assert_select ".collection-pages [aria-current=page]", /2/
    assert_select ".collection-pages a[href*='/brothers/#{@owner.token}/library']"
  end

  test "a card opened from the owner's grid carries the grid and the owner's token" do
    publish_sets_draft

    get brother_collection_path(locale: :en, token: @owner.token, state: %w[all new])

    link = css_select(".collection-grid a.card-link").first["href"]
    assert_includes link, "grid%5Bbrother%5D=#{@owner.token}"
    assert_not_includes link, "new"
    assert_not_includes link, "seen"
  end

  test "with no season published the owner's collection is the no-season line" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    get brother_collection_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select ".collection-none", /No season of cards is published yet/
  end

  test "a hidden owner's collection is the same unavailable page as the profile, with a 404" do
    publish_sets_draft
    get brother_path(locale: :en, token: "A" * 24)
    unknown = css_select("main").to_html

    get brother_collection_path(locale: :en, token: "A" * 24)
    assert_response :not_found
    assert_equal unknown, css_select("main").to_html

    banned = accounts_players(:banned)
    get brother_collection_path(locale: :en, token: banned.token)
    assert_response :not_found
    assert_equal unknown, css_select("main").to_html

    @owner.update!(visibility: "private")
    get brother_collection_path(locale: :en, token: @owner.token)
    assert_response :not_found
    assert_equal unknown, css_select("main").to_html

    sign_in(@owner)
    get brother_collection_path(locale: :en, token: @owner.token)
    assert_response :success
  end

  test "the page offers no write route" do
    publish_sets_draft
    path = brother_collection_path(locale: :en, token: @owner.token)

    post path
    assert_response :not_found
    patch path
    assert_response :not_found
  end

  test "the profile offers no full collection without a season" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get brother_path(locale: :fr, token: @owner.token)

    assert_select "a[href=?]", brother_collection_path(locale: :fr, token: @owner.token), false
  end

  test "the profile offers the full collection after its sets" do
    publish_sets_draft
    get brother_path(locale: :fr, token: @owner.token)
    assert_select ".profile-section__action a.button[href=?]", brother_collection_path(locale: :fr, token: @owner.token), "Voir la collection complète"
    get brother_path(locale: :en, token: @owner.token)
    assert_select ".profile-section__action a.button", "See the full collection"
  end

  test "a banned owner's profile is the same unavailable page as an unknown token" do
    publish_sets_draft
    banned = accounts_players(:banned)
    banned.update_columns(persona_name: "Banned Brother")

    get brother_path(locale: :en, token: "A" * 24)
    unknown = css_select("main").to_html

    get brother_path(locale: :en, token: banned.token)
    assert_response :not_found
    assert_equal unknown, css_select("main").to_html
    assert_select "title", "Profile not available"
    assert_not_includes response.body, "Banned Brother"

    get brother_set_path(locale: :en, token: banned.token, kind: "theme", key: "rpg")
    assert_response :not_found
    assert_equal unknown, css_select("main").to_html
  end

  test "a profile banned by a moderator is the unavailable page, and shows again once unbanned" do
    publish_sets_draft
    moderator = accounts_players(:moderator)

    Accounts::BanPlayer.new.call(staff: moderator, player: @owner, reason: "Cheating").value!
    get brother_path(locale: :en, token: @owner.token)

    assert_response :not_found
    assert_select "title", "Profile not available"
    assert_not_includes response.body, "Gabe the Brave"

    Accounts::UnbanPlayer.new.call(staff: moderator, player: @owner).value!
    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_includes response.body, "Gabe the Brave"
  end

  test "a private or friends-only owner is the unavailable page for a visitor and a stranger, not for the owner" do
    publish_sets_draft
    stranger = Accounts::Player.create!(steam_id: "76561197960390101")
    get brother_path(locale: :en, token: "A" * 24)
    unknown = css_select("main").to_html

    %w[private friends_only].each do |visibility|
      @owner.update!(visibility:)

      get brother_path(locale: :en, token: @owner.token)
      assert_response :not_found
      assert_equal unknown, css_select("main").to_html, visibility

      get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg")
      assert_response :not_found
      assert_equal unknown, css_select("main").to_html, visibility

      sign_in(stranger)
      get brother_path(locale: :en, token: @owner.token)
      assert_response :not_found
      delete session_path(locale: :en)

      sign_in(@owner)
      get brother_path(locale: :en, token: @owner.token)
      assert_response :success
      delete session_path(locale: :en)
    end
  end

  test "a friends-only owner is shown to a friend, a private one is not" do
    publish_sets_draft
    friend = Accounts::Player.create!(steam_id: "76561197960390102")
    Game::Friendship.create!(low_player_id: [ @owner.id, friend.id ].min, high_player_id: [ @owner.id, friend.id ].max)
    @owner.update!(visibility: "friends_only")
    sign_in(friend)

    get brother_path(locale: :en, token: @owner.token)
    assert_response :success
    assert_select "h1", "Gabe the Brave"

    @owner.update!(visibility: "private")
    get brother_path(locale: :en, token: @owner.token)
    assert_response :not_found
  end

  test "staff read a private, a friends-only and a banned owner's profile, a deleted one's not" do
    publish_sets_draft
    banned = accounts_players(:banned)
    banned.update_columns(persona_name: "Banned Brother")

    [ :moderator, :administrator ].each do |role|
      sign_in(accounts_players(role))

      %w[private friends_only].each do |visibility|
        @owner.update!(visibility:)
        get brother_path(locale: :en, token: @owner.token)
        assert_response :success, [ role, visibility ]
        assert_select "h1", "Gabe the Brave"
        get brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg")
        assert_response :success, [ role, visibility ]
      end

      get brother_path(locale: :en, token: banned.token)
      assert_response :success, role
      assert_select "h1", "Banned Brother"
      delete session_path(locale: :en)
    end

    sign_in(accounts_players(:moderator))
    Accounts::DeletePlayer.new.call(player: @owner).value!
    get brother_path(locale: :en, token: @owner.reload.token)
    assert_response :not_found
    assert_select "h1", "Profile not available"
  end

  test "the profile carries no visibility line, for its owner or a visitor" do
    publish_sets_draft

    get brother_path(locale: :en, token: @owner.token)
    assert_no_match(/Visible to|moderation team/, response.body)

    @owner.update!(visibility: "private")
    sign_in(@owner)
    get brother_path(locale: :fr, token: @owner.token)
    assert_response :success
    assert_no_match(/Profil privé|modération le voyez/, response.body)
  end

  test "a banned member of staff reads a hidden profile as the visitor they become" do
    publish_sets_draft
    moderator = accounts_players(:moderator)
    @owner.update!(visibility: "private")
    sign_in(moderator)
    moderator.update!(banned_at: Time.current)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :not_found
    assert_nil session[:player_id]
  end

  test "in French: the fallback title, the French labels and plurals" do
    season = publish_sets_draft
    @owner.update_columns(persona_name: nil, created_at: Time.zone.local(2026, 3, 2, 12))
    code = Accounts::PublicProfile.code(@owner.token)

    get brother_path(locale: :fr, token: @owner.token)

    assert_select "title", "Joueur #{code}"
    assert_select "h1", "Joueur #{code}"
    assert_select ".profile-band__since", "Membre depuis mars 2026"
    assert_equal [ [ "Cartes", "0/#{card_total(season)}" ], [ "Sets complets", "0" ], [ "Succès", "0/10" ] ], keys
    assert_select "section.profile-stats[aria-label=Statistiques]"
    assert_equal [ "Raretés", "Activité" ], css_select(".profile-stats__kicker").map(&:text)
    assert_equal [ "Capsules ouvertes", "Premières découvertes", "Échanges conclus" ],
      figures(".profile-stats__grid:not(.profile-stats__grid--rarities)").map(&:first)
    assert_equal [ "Succès", "Sets" ], css_select("h2").map(&:text)
    assert_select "#profile-achievements-heading ~ .achievements__head .visually-hidden", "0 succès obtenu sur 10"
    assert_select ".profile-section__aside", "0 set entamé"

    set_members(season, "pirates").each { |id| hold(@owner, id, 1) }
    unlock("first_booster", 1.day.ago)
    get brother_path(locale: :fr, token: @owner.token)
    assert_equal "1", key("Sets complets")
    assert_select ".profile-section__label", "Derniers obtenus"
    assert_select ".profile-section__aside", "2 sets entamés"
    assert_select ".profile-sets .set-tile > .visually-hidden", "Pirates, thème, 8 cartes sur 8, complet"

    get brother_set_path(locale: :fr, token: @owner.token, kind: "theme", key: "pirates")
    assert_select "h1", "Pirates · Joueur #{code}"
    assert_select "title", "Pirates · Joueur #{code} · Gameble"
    assert_select ".set-album__stamp", "Complet"

    get brother_path(locale: :en, token: @owner.token)
    assert_select "h1", "Player #{code}"
    assert_select ".profile-band__since", "Member since March 2026"
    assert_select ".profile-section__aside", "2 sets started"
  end

  [ "\u200B", "\u202E\u2066", "\u3164", "\u3000 \u2800" ].each do |name|
    test "a stored persona name of #{name.inspect}, nothing visible, falls back to Player <code>" do
      publish_sets_draft
      @owner.update_columns(persona_name: name)
      code = Accounts::PublicProfile.code(@owner.token)

      get brother_path(locale: :en, token: @owner.token)

      assert_select "title", "Player #{code}"
      assert_select "h1", "Player #{code}"
    end
  end

  test "a stored persona name is shown cleaned of its invisible characters" do
    publish_sets_draft
    @owner.update_columns(persona_name: "\u202EGa\u200Bbe\u3000the Brave")

    get brother_path(locale: :en, token: @owner.token)

    assert_select "h1", "Gabe the Brave"
    assert_no_match(/\u202E|\u200B/, response.body)
  end

  test "the persona name is escaped as user content" do
    publish_sets_draft
    @owner.update_columns(persona_name: "<b>Gabe</b> & co")

    get brother_path(locale: :en, token: @owner.token)

    assert_select "h1", "<b>Gabe</b> & co"
    assert_select "h1 b", false
    assert_select "title", "<b>Gabe</b> & co"
    assert_includes response.body, "&lt;b&gt;Gabe&lt;/b&gt; &amp; co"
  end

  test "no database id, no Steam id; the token only in URLs" do
    season = publish_sets_draft
    hold(@owner, set_members(season, "rpg").first, 2)
    ids = [ @owner.id ] + Catalog::Set.where(season_id: season.id).ids + Catalog::CardSeason.where(season_id: season.id).ids

    [ brother_path(locale: :en, token: @owner.token), brother_set_path(locale: :en, token: @owner.token, kind: "theme", key: "rpg") ].each do |path|
      get path

      assert_not_includes response.body, @owner.steam_id
      assert_select ".collection [data-id], .profile [data-id]", false
      without_urls = response.body.gsub(/(href|action|value)="[^"]*"/, "")
      assert_not_includes without_urls, @owner.token
      html = css_select("main").sole.to_html
      ids.each do |id|
        assert_no_match(/\b#{id}\b/, html.gsub(/<dd class="profile-figure__value">.*?<\/dd>|<p class="achievements__count"[^>]*>.*?<\/p>|\d+ \/ \d+|\d+ of \d+|\d+ cards?|\d+ sets?|\b(19|20)\d\d\b|×\d+|\d+ cop(y|ies)|seed-\d+-\d+|data-card-art-(width|height)-value="\d+"|width="\d+"|height="\d+"|\?page=\d+|page=\d+|\/seasons\/\d+|[Ss]eason \d+/, ""))
      end
    end
  end

  test "a visitor's profile costs fifteen queries whatever the owner's history, a signed-in viewer's eight more, a showcase one more" do
    season = publish_sets_draft
    set_members(season, "horror").last(2).each { |id| hold(@owner, id, 1) }
    unlock("first_booster", 1.day.ago)

    # Owner by token, published season; the summary, the season's card
    # count, the achievements earned, the showcase, the rarities, the
    # activity, the owner's started sets, those sets, their cards and the
    # faces of those shown; the themes' names; the owner's earned titles and
    # their chosen one.
    assert_request_queries(15) { get brother_path(locale: :en, token: @owner.token) }
    assert_response :success
    assert_select ".profile-sets .set-tile", minimum: 1

    hold_started_sets(season)
    open_packs(season, 3)
    %w[first_epic first_trade boosters_10 first_repost].each { unlock(it, 1.hour.ago) }
    assert_request_queries(15) { get brother_path(locale: :en, token: @owner.token) }
    assert_select ".profile-sets .set-tile", 5
    assert_select ".profile-achievements .achievement", 4

    sign_in(accounts_players(:moderator))
    # The same, the viewer's lookup and the top bar's four (reserve count,
    # next pack, copies per tier, rarity legend), the tab bar's trades
    # waiting, and the viewer's friendship and invitations with the owner.
    assert_request_queries(23) { get brother_path(locale: :en, token: @owner.token) }

    # The chosen cards' views, however many.
    held = Game::Holding.where(player_id: @owner.id).limit(Game::ChosenShowcase::SIZE).pluck(:card_season_id)
    held.each { Game::AddToShowcase.new.call(player: @owner, card_season_id: it).value! }
    assert_request_queries(24) { get brother_path(locale: :en, token: @owner.token) }
    assert_select ".profile-showcase .card", held.size
    assert_response :success

    # The owner's move buttons cost nothing more.
    sign_in(@owner)
    assert_request_queries(22) { get brother_path(locale: :en, token: @owner.token) }
    assert_select ".profile-showcase__moves", held.size
  end

  test "the summary counts every edition: a game gone from the season, and a set completed through an earlier edition of a member" do
    season = publish_sets_draft
    pirates = set_members(season, "pirates")
    earlier = Catalog::CardSeason.insert_all!([ { card_id: Catalog::CardSeason.find(pirates.first).card_id, season_id: catalog_seasons(:one).id,
      prestige_score: 0.5, rating: 90, rarity: "rare", number: 900 } ], returning: :id).rows.flatten.sole
    hold(@owner, earlier, 1)
    pirates.drop(1).each { hold(@owner, it, 1) }
    hold(@owner, catalog_card_seasons(:portal_one).id, 2)

    get brother_path(locale: :en, token: @owner.token)

    assert_equal [ "#{pirates.size + 1}/#{card_total(season)}", "1" ], [ key("Cards"), key("Complete sets") ]
  end

  test "the card count stops at the season's total when older editions add games" do
    season = publish_sets_draft
    Catalog::CardSeason.where(season_id: season.id).where.not(rarity: nil).pluck(:id).each { hold(@owner, it, 1) }
    hold(@owner, catalog_card_seasons(:portal_one).id, 1)

    get brother_path(locale: :en, token: @owner.token)

    assert_equal "#{card_total(season)}/#{card_total(season)}", key("Cards")
  end

  test "staff see the banned line on a banned player's profile, no one else does" do
    publish_sets_draft
    banned = accounts_players(:banned)

    sign_in(accounts_players(:moderator))
    get brother_path(locale: :en, token: banned.token)
    assert_select ".profile-band__banned", "Banned player: only staff can see this profile"
    get brother_path(locale: :en, token: @owner.token)
    assert_select ".profile-band__banned", false
    delete session_path(locale: :en)

    get brother_path(locale: :en, token: banned.token)
    assert_response :not_found
    assert_select ".profile-band__banned", false
    sign_in(@owner)
    get brother_path(locale: :fr, token: banned.token)
    assert_response :not_found
    assert_select ".profile-band__banned", false
  end

  test "the banned line is in French for staff" do
    publish_sets_draft
    sign_in(accounts_players(:administrator))

    get brother_path(locale: :fr, token: accounts_players(:banned).token)

    assert_select ".profile-band__banned", "Joueur banni : visible par les officiers de la Confrérie seulement"
  end

  test "the chosen cards show under VITRINE after the identity band, in their order, each leading to its detail with the owner's token, and the GET writes nothing" do
    season = publish_sets_draft
    cards = set_members(season, "pirates").first(3)
    cards.each { hold(@owner, it, 1) }
    [ cards[2], cards[0], cards[1] ].each { Game::AddToShowcase.new.call(player: @owner, card_season_id: it).value! }
    slugs = Catalog::CardSeason.where(id: cards).includes(:card).to_h { [ it.id, it.card.slug ] }

    written = written_statements { get brother_path(locale: :fr, token: @owner.token) }

    assert_response :success
    assert_empty written
    assert_equal [ "Vitrine", "Succès", "Sets" ], css_select("h2").map(&:text)
    assert_select "header.profile-band + section.profile-section h2#profile-showcase-heading", "Vitrine"
    links = css_select(".profile-showcase .profile-showcase__slot > a.card-link")
    expected = [ cards[2], cards[0], cards[1] ].map { "/fr/cards/#{slugs.fetch(it)}/seasons/#{season.number}?brother=#{@owner.token}" }
    assert_equal expected, links.map { it["href"] }
    assert_select ".profile-showcase .card.card--grid", 3
    assert_select ".profile-showcase .card-rays, .profile-showcase .card-float", false
    assert_select "[style]", false
    cards.each { assert_no_match(/\b#{it}\b/, links.map(&:to_html).join.gsub(/\/seasons\/\d+|data-card-art-(width|height)-value="\d+"|\b(19|20)\d\d\b/, "")) }
  end

  test "no card chosen, no VITRINE section" do
    hold(@owner, catalog_card_seasons(:portal_one).id, 1)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select "#profile-showcase-heading, .profile-showcase", false
  end

  def choose_three
    season = publish_sets_draft
    cards = set_members(season, "pirates").first(3)
    cards.each { hold(@owner, it, 1) }
    cards.each { Game::AddToShowcase.new.call(player: @owner, card_season_id: it).value! }
    views = Catalog::CardViews.call(cards, locale: :en)
    cards.map { views.fetch(it) }
  end

  # Each slot's move buttons as [ accessible name, direction ].
  def move_buttons
    css_select(".profile-showcase__slot").map do |slot|
      slot.css(".profile-showcase__moves form:not([hidden])").map { [ it.at_css("button")["aria-label"], it.at_css("input[name=direction]")["value"] ] }
    end
  end

  def showcase_slugs = css_select(".profile-showcase__slot > a.card-link").map { it["href"][%r{/cards/([^/]+)/}, 1] }

  def focused = css_select(".profile-showcase [autofocus]").map { it["aria-label"] }

  test "on their own profile the owner moves each card left or right, but not past either end, and the GET writes nothing" do
    a, b, c = choose_three
    sign_in(@owner)

    written = written_statements { get brother_path(locale: :en, token: @owner.token) }

    assert_response :success
    assert_empty written
    assert_equal [
      [ [ "Move #{a.title} right", "later" ] ],
      [ [ "Move #{b.title} left", "earlier" ], [ "Move #{b.title} right", "later" ] ],
      [ [ "Move #{c.title} left", "earlier" ] ]
    ], move_buttons
    assert_equal "/en/cards/#{a.id}/seasons/#{a.season_number}/showcase", css_select(".profile-showcase__moves form").first["action"]
    assert_select ".profile-showcase__moves form input[name=_method][value=patch]", 6
    assert_select ".profile-showcase__moves button svg.pixel-icon", 6
    assert_equal [ [ "earlier", true ], [ "later", false ], [ "earlier", false ], [ "later", false ], [ "earlier", false ], [ "later", true ] ],
      css_select(".profile-showcase__moves form").map { [ it["data-direction"], it.has_attribute?("hidden") ] }
    assert_select ".profile-showcase [autofocus]", false
    assert_select "[style]", false
  end

  test "on their own profile the owner can drag the cards: each slot names its card and where to send its place, an info mark says so, and a polite region announces the move" do
    a, b, c = choose_three
    sign_in(@owner)

    get brother_path(locale: :en, token: @owner.token)

    section = css_select("section[data-controller=showcase-order]").sole
    assert_equal "%{title} is now in place %{position} of %{count}.", section["data-showcase-order-announcement-value"]
    assert_equal "The new order could not be saved.", section["data-showcase-order-failed-value"]
    assert_select section, "ul.profile-showcase--sortable[data-showcase-order-target=list]"
    slots = css_select(".profile-showcase__slot[data-showcase-order-target=slot]")
    assert_equal [ a, b, c ].map(&:title), slots.map { it["data-title"] }
    assert_equal [ a, b, c ].map { "/en/cards/#{it.id}/seasons/#{it.season_number}/showcase" }, slots.map { it["data-url"] }
    assert slots.all? { it["data-action"].include?("pointerdown->showcase-order#press") }
    assert_select ".profile-showcase__head h2#profile-showcase-heading + details.profile-showcase__info summary" do
      assert_select "svg.pixel-icon"
      assert_select ".visually-hidden", "How to change the order"
    end
    assert_select ".profile-showcase__info-text", "Drag the cards to change their order, or move a card one place with the arrows under it."
    assert_select "p.visually-hidden[role=status][data-showcase-order-target=status]", ""
    assert_select "[style]", false
  end

  test "the info mark speaks French in French" do
    choose_three
    sign_in(@owner)

    get brother_path(locale: :fr, token: @owner.token)

    assert_select ".profile-showcase__info summary .visually-hidden", "Comment changer l'ordre"
    assert_select ".profile-showcase__info-text", /\AFaites glisser les cartes/
    assert_equal "%{title} est maintenant à la place %{position} sur %{count}.", css_select("[data-controller=showcase-order]").sole["data-showcase-order-announcement-value"]
  end

  test "the move buttons speak French in French" do
    choose_three
    sign_in(@owner)

    get brother_path(locale: :fr, token: @owner.token)

    ids = Game::ChosenShowcase.call(@owner)
    views = Catalog::CardViews.call(ids, locale: :fr)
    titles = ids.map { views.fetch(it).title }
    assert_select "form[hidden] button[aria-label=?]", "Déplacer #{titles.first} vers la gauche"
    assert_select "button[aria-label=?]", "Déplacer #{titles.first} vers la droite"
    assert_select "button[aria-label=?]", "Déplacer #{titles.last} vers la gauche"
  end

  test "a single chosen card has no move button" do
    choose_three
    Game::ChosenShowcase.call(@owner).drop(1).each { Game::RemoveFromShowcase.new.call(player: @owner, card_season_id: it).value! }
    sign_in(@owner)

    get brother_path(locale: :en, token: @owner.token)

    assert_select ".profile-showcase .card", 1
    assert_select ".profile-showcase__moves", false
    assert_select "[data-controller=showcase-order], [data-showcase-order-target], .profile-showcase__info", false
  end

  test "no one but the owner sees a move button: not another player, not staff, not a visitor" do
    choose_three
    stranger = Accounts::Player.create!(steam_id: "76561197960390188")

    get brother_path(locale: :en, token: @owner.token)
    assert_select ".profile-showcase .card", 3
    assert_select ".profile-showcase__moves, .profile-showcase__move, .profile-showcase__info, [data-controller=showcase-order], [data-showcase-order-target]", false

    [ stranger, accounts_players(:moderator), accounts_players(:administrator) ].each do |viewer|
      sign_in(viewer)
      get brother_path(locale: :en, token: @owner.token)
      assert_select ".profile-showcase .card", 3
      assert_select ".profile-showcase__moves, .profile-showcase__move, .profile-showcase__info, [data-controller=showcase-order], [data-showcase-order-target]", false
    end
  end

  test "after a move the profile comes back in the new order with the focus on the button pressed, or the card's other one at the edge" do
    a, b, c = choose_three
    sign_in(@owner)
    profile = brother_path(locale: :en, token: @owner.token)

    patch card_showcase_path(locale: :en, slug: a.id, number: a.season_number), params: { direction: "later" }, headers: { "HTTP_REFERER" => profile }
    assert_redirected_to profile
    follow_redirect!

    assert_equal [ b, a, c ].map(&:id), showcase_slugs
    assert_equal [ "Move #{a.title} right" ], focused

    patch card_showcase_path(locale: :en, slug: a.id, number: a.season_number), params: { direction: "earlier" }, headers: { "HTTP_REFERER" => profile }
    follow_redirect!

    assert_equal [ a, b, c ].map(&:id), showcase_slugs
    assert_equal [ "Move #{a.title} right" ], focused

    get profile
    assert_empty focused
  end
end
