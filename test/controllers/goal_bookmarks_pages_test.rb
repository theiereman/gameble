require "test_helper"
require_relative "../support/custom_sets"
require_relative "../support/game_packs"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

# The numbered bookmarks of the signed-in player's goals on every card of a
# goal's set, owned or not, on their own pages only: the grid and its
# OBJECTIFS filter, the albums (a goal's own album leaves its bookmark
# off), the card detail and its OBJECTIFS row, the opened capsule and the
# goal sets' tiles. Never on another player's pages or for a visitor.
class GoalBookmarksPagesTest < ActionDispatch::IntegrationTest
  include CustomSets
  include GamePacks
  include GameSets
  include LibraryRequests
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @portal = catalog_card_seasons(:portal_one).id
    @common = catalog_card_seasons(:common_card_one).id
  end

  def add(player = @player, **aim) = Game::AddGoal.new.call(player:, **aim).value!

  def roguelike(members = [ @portal, @common ]) = insert_set(members, { complete: members.size }, key: "roguelike", params: { "theme" => "roguelike" })

  def three_games = [ catalog_cards(:portal).id, catalog_cards(:common_card).id, catalog_cards(:uncommon_card).id ]

  def card_title(card_season_id) = Catalog::CardText.find_by!(card_id: Catalog::CardSeason.find(card_season_id).card_id, locale: "en").title

  # Each grid slot's card as [ title, its bookmarks' numbers ].
  def marked_slots(selector = ".collection-grid > li.collection-slot")
    css_select(selector).map do |slot|
      [ slot.at_css(".card__title").text, slot.css(".card > .card__goals > .goal-bookmark").map { it.text.to_i } ]
    end
  end

  def marks_of(title) = marked_slots.to_h.fetch(title)

  def link_label(title) = css_select(".collection-grid a.card-link").find { it.at_css(".card__title").text == title }["aria-label"]

  def goal_chips = css_select("fieldset[data-group=goals] .filter-chip")

  def filter_count = css_select(".filters__count [data-collection-filters-target=number]").sole.text

  test "the grid marks every card of a goal's set, owned or not, from the top of its art, numbers in order and at full colour" do
    roguelike
    hold(@player, @common)
    add(kind: "studio", key: "valve")
    add(kind: "theme", key: "roguelike")
    sign_in(@player)

    get library_cards_path(locale: :en)

    assert_equal [ 1, 2 ], marks_of("Portal")
    assert_equal [ 2 ], marks_of(card_title(@common))
    assert_equal [], marks_of(card_title(catalog_card_seasons(:rare_card_one).id))
    assert_select ".card--not-owned > .card__body + .card__lock + .card__goals[aria-hidden=true] > .goal-bookmark.goal-tone--1:not(.goal-bookmark--large) + .goal-bookmark.goal-tone--2"
    assert_select ".card:not(.card--not-owned) > .card__body + .card__effects + .card__goals > .goal-bookmark.goal-tone--2"
    assert_select ".card__body .card__goals", false
    assert_equal "Portal, 2007, Epic, season 1, not owned, goal 1: Valve, goal 2: Roguelike", link_label("Portal")
    assert_match(/, season 1, goal 2: Roguelike\z/, link_label(card_title(@common)))
    assert_select "[style]", false
  end

  test "OBJECTIFS sits between state and rarity, a chip per goal named by its number and set; checking one keeps its set's cards, owned and missing" do
    roguelike
    custom_set = create_custom_set(@player)
    add(kind: "studio", key: "valve")
    add(custom_set: custom_set.token)
    add(kind: "theme", key: "roguelike")
    sign_in(@player)

    get library_cards_path(locale: :fr)
    assert_select "fieldset[data-group=state] + fieldset.filters__group[data-group=goals][data-collection-filters-target=group] + fieldset[data-group=rarity]"
    assert_select "fieldset[data-group=goals] > legend", "Objectifs"
    assert_equal [ "studio:valve", custom_set.token, "theme:roguelike" ], goal_chips.map { it.at_css("input[name='goals[]']")["value"] }
    assert_equal [ "Objectif 1 : Valve", "Objectif 2 : Mes favoris", "Objectif 3 : Roguelike" ],
      goal_chips.map { it.at_css("input")["aria-label"] }
    assert_equal [ "1", "2", "3" ], goal_chips.map { it.at_css(".filter-chip__text > .goal-bookmark.goal-bookmark--small[aria-hidden=true]").text }
    assert_equal [ "Valve", "Mes favoris", "Roguelike" ], goal_chips.map { it.at_css(".filter-chip__text").children.last.text }

    get library_cards_path(locale: :en, goals: [ "theme:roguelike" ])
    assert_equal [ "Portal", card_title(@common) ].sort, marked_slots.map(&:first).sort
    assert_equal "1", filter_count
    assert_select "details.filters__zone[open]"
    assert_equal [ "theme:roguelike" ], css_select("fieldset[data-group=goals] input[checked]").map { it["value"] }
    grid = Rack::Utils.parse_nested_query(URI(css_select(".collection-grid a.card-link").first["href"]).query)["grid"]
    assert_equal [ "theme:roguelike" ], grid["goals"]

    get library_cards_path(locale: :en, goals: [ "studio:valve", custom_set.token ])
    assert_equal [ "Portal", *Catalog::CardSeason.where(card_id: custom_set_card_ids(custom_set)).order(:number).map { card_title(it.id) } ].sort,
      marked_slots.map(&:first).sort
    assert_equal "2", filter_count
  end

  test "an unknown goal value, another player's custom set or a goal's position filters nothing; a visitor and a player without goals get no OBJECTIFS" do
    roguelike
    other = create_custom_set(accounts_players(:moderator))
    add(kind: "theme", key: "roguelike")
    sign_in(@player)

    get library_cards_path(locale: :en, goals: [ "theme:gone", other.token, "1", "theme:roguelike:x" ])
    assert_equal 5, marked_slots.size
    assert_select ".filters__count[hidden]"
    assert_select "fieldset[data-group=goals] input[checked]", false

    Game::RemoveGoal.new.call(player: @player, kind: "theme", key: "roguelike").value!
    get library_cards_path(locale: :en)
    assert_select "fieldset[data-group=goals]", false
    assert_select ".card__goals", false

    delete session_path(locale: :en)
    get library_cards_path(locale: :en, goals: [ "theme:roguelike" ])
    assert_equal 5, marked_slots.size
    assert_select "fieldset[data-group=goals]", false
    assert_select ".card__goals", false
  end

  test "the next page of a grid filtered on a goal, appended by stream, marks its cards" do
    season, ids = published_cards(CollectionGridLoading::GRID_SIZE + 2)
    insert_set(ids, { complete: ids.size }, key: "board", params: { "theme" => "board" }, season:)
    add(kind: "theme", key: "board")
    sign_in(@player)

    get library_cards_path(locale: :en, goals: [ "theme:board" ], page: 2), as: :turbo_stream

    assert_response :success
    assert_equal 2, css_select("turbo-stream[target=collection-slots] li.collection-slot .card > .card__goals > .goal-bookmark.goal-tone--1").size
  end

  test "an album marks the cards other goals hold; a goal's own album leaves its own bookmark off" do
    roguelike
    insert_set([ @portal ], { complete: 1 }, key: "horror", params: { "theme" => "horror" })
    custom_set = create_custom_set(@player, card_ids: three_games)
    add(kind: "studio", key: "valve")
    add(kind: "theme", key: "roguelike")
    add(custom_set: custom_set.token)
    sign_in(@player)

    get library_set_path(locale: :en, kind: "theme", key: "horror")
    assert_equal [ [ "Portal", [ 1, 2, 3 ] ] ], marked_slots(".set-album__grid > li")

    get library_set_path(locale: :en, kind: "theme", key: "roguelike")
    assert_equal [ [ "Portal", [ 1, 3 ] ], [ card_title(@common), [ 3 ] ] ], marked_slots(".set-album__grid > li")
    assert_match(/, goal 1: Valve, goal 3: Mes favoris\z/, css_select(".set-album__grid a.card-link").first["aria-label"])

    get custom_set_path(locale: :en, token: custom_set.token)
    assert_equal [ [ "Portal", [ 1, 2 ] ], [ card_title(@common), [ 2 ] ], [ card_title(catalog_card_seasons(:uncommon_card_one).id), [] ] ],
      marked_slots(".set-album__grid > li")
  end

  test "another player's collection, album and tiles carry no bookmark, neither the viewer's nor the owner's" do
    roguelike
    viewer = accounts_players(:moderator)
    hold(@player, @common)
    add(kind: "theme", key: "roguelike")
    add(viewer, kind: "theme", key: "roguelike")
    sign_in(viewer)

    get brother_collection_path(locale: :en, token: @player.token, goals: [ "theme:roguelike" ])
    assert_equal 5, marked_slots.size
    assert_select ".card__goals", false
    assert_select "fieldset[data-group=goals]", false

    get brother_set_path(locale: :en, token: @player.token, kind: "theme", key: "roguelike")
    assert_select ".set-album__grid .card"
    assert_select ".card__goals", false

    get brother_path(locale: :en, token: @player.token)
    assert_select ".set-tile"
    assert_select ".set-tile--goal, .set-tile .goal-bookmark", false
  end

  test "the card detail carries the large bookmarks and an OBJECTIFS row after SETS linking each goal's album; a visitor gets neither" do
    custom_set = create_custom_set(@player, card_ids: three_games)
    add(kind: "studio", key: "valve")
    add(custom_set: custom_set.token)
    sign_in(@player)

    get card_path(locale: :fr, slug: "portal")

    assert_equal [ "1", "2" ], css_select(".card-detail__card .card.card--l > .card__goals > .goal-bookmark.goal-bookmark--large").map(&:text)
    row = css_select(".card-detail__fact:has(> dt:contains('Sets')) + .card-detail__fact.card-detail__fact--goals").sole
    assert_equal "Objectifs", row.at_css("dt").text
    links = row.css("dd > ul.card-detail__goals > li > a.card-detail__goal")
    assert_equal [ "/fr/library/studio/valve", "/fr/library/custom-sets/#{custom_set.token}" ], links.map { it["href"] }
    assert_equal %w[goal-tone--1 goal-tone--2], links.map { it["class"][/goal-tone--\d/] }
    assert_equal [ "Valve", "Mes favoris" ], links.map { it.children.last.text }
    assert_equal [ "Objectif 1 : Valve", "Objectif 2 : Mes favoris" ], links.map { it["aria-label"] }
    assert_equal 2, row.css(".goal-bookmark.goal-bookmark--small[aria-hidden=true]").size

    get card_path(locale: :fr, slug: "golden-crown")
    assert_select ".card-detail__fact--goals", false
    assert_select ".card__goals", false

    delete session_path(locale: :fr)
    get card_path(locale: :fr, slug: "portal")
    assert_select ".card__goals", false
    assert_select ".card-detail__fact--goals", false
  end

  test "the card detail's ◀ ▶ browse the grid filtered on a goal" do
    roguelike
    add(kind: "theme", key: "roguelike")
    sign_in(@player)

    get card_season_path(locale: :en, slug: "portal", number: 1, grid: { goals: [ "theme:roguelike" ] })

    assert_select ".card-detail__position", /· 2 \/ 2 ·/
  end

  test "an opening's cards carry their goal words and their faces the bookmarks; the restored capsule and the pack's page too" do
    roguelike([ @portal, *unheld_cards(1) ])
    add(kind: "theme", key: "roguelike")
    pack = create_pack(@player, cards: fixture_tier_ids)
    sign_in(@player)

    post packs_path(locale: :en), headers: { "Accept" => "application/json", "Idempotency-Key" => SecureRandom.uuid }

    cards = response.parsed_body["cards"]
    assert_equal [ "", "", "", "goal 1: Roguelike", "" ], cards.map { it["goals"] }
    cards.each_with_index do |card, index|
      card["faces"].each do |size, html|
        marks = Nokogiri::HTML5.fragment(html).css(".card > .card__goals > .goal-bookmark").map(&:text)
        assert_equal(index == 3 ? [ "1" ] : [], marks, "#{size} face of card #{index}")
      end
    end

    get booster_path(locale: :en, pack: pack.token)
    assert_equal [ "", "", "", "goal 1: Roguelike", "" ], css_select("template[data-booster-target=card]").map { it["data-goals"] }
    faces = css_select("template[data-booster-target=face][data-index='3']")
    assert_equal 3, faces.size
    faces.each { assert_equal 1, Nokogiri::HTML5.fragment(it.inner_html).css(".card__goals > .goal-bookmark.goal-tone--1").size }

    get pack_path(locale: :en, token: pack.token)
    assert_equal [ [ "Portal", [ 1 ] ] ], marked_slots(".pack-result__card").select { it.last.any? }
    assert_match(/, goal 1: Roguelike\z/, css_select(".pack-result__card a.card-link")[3]["aria-label"])
  end

  test "a goal set's tile carries the goal edge and the large bookmark on both faces, and its name says the goal after the kind" do
    insert_set([ @portal, @common, catalog_card_seasons(:uncommon_card_one).id ], { bronze: 1, complete: 3 }, key: "roguelike", params: { "theme" => "roguelike" })
    custom_set = create_custom_set(@player)
    hold(@player, @portal)
    hold(@player, @common)
    add(custom_set: custom_set.token)
    add(kind: "theme", key: "roguelike")
    sign_in(@player)

    get library_path(locale: :fr)
    tile = css_select(".custom-sets a.set-tile").sole
    assert_includes tile["class"].split, "set-tile--goal"
    assert_includes tile["class"].split, "goal-tone--1"
    assert_equal [ "1", "1" ], tile.css(".set-tile__face .set-tile__head > .set-tile__goal > .goal-bookmark.goal-bookmark--large + .set-tile__title").map { it.previous_element.text }
    assert_equal "Mes favoris, set perso, objectif 1, 1 carte sur 3", tile.css("> .visually-hidden").text

    get library_in_progress_path(locale: :fr), headers: { "Turbo-Frame" => "set-entry-in-progress" }
    tiles = css_select("#set-entry-in-progress-title ~ ul.set-tiles a.set-tile, #set-entry-completed-title ~ ul.set-tiles a.set-tile")
    assert_equal [ "goal-tone--2", nil ], tiles.map { it["class"][/goal-tone--\d/] }
    roguelike_tile = tiles.find { it.at_css(".set-tile__name").text == "Roguelike" }
    assert_match(/\ARoguelike, thème, objectif 2, 2 cartes sur 3/, roguelike_tile.css("> .visually-hidden").text)

    get library_path(locale: :fr, q: "rogue")
    assert_select "#set-results-title ~ ul.set-tiles a.set-tile.set-tile--goal.goal-tone--2"

    Game::RemoveGoal.new.call(player: @player, custom_set: custom_set.token).value!
    get library_path(locale: :fr)
    assert_select ".custom-sets .set-tile--goal", false
    assert_select ".custom-sets .set-tile .goal-bookmark", false
  end

  private
    def custom_set_card_ids(custom_set)
      Game::CustomSetGame.where(custom_set_id: custom_set.id).pluck(:card_id)
    end
end
