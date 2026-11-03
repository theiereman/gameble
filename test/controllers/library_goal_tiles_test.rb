require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

# OBJECTIFS at the head of the collection entry: a tile per goal, linking its
# album, its missing cards as thumbnails opening their detail; with no goal,
# the three started sets closest to complete, each one tap from being a
# goal. EN COURS leaves the goal sets out.
class LibraryGoalTilesTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include CustomSets
  include GameSets
  include LibraryRequests
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @season, @cards = published_cards(600)
  end

  def take(count) = @cards.shift(count)

  def theme(key, size) = take(size).tap { insert_theme(it, key:, season: @season) }

  def named(kind, name, size) = take(size).tap { insert_set(it, { complete: size }, kind:, key: name.parameterize, params: { kind => name }, season: @season) }

  def add(**aim) = Game::AddGoal.new.call(player: @player, **aim).value!

  def card_ids(card_season_ids) = Catalog::CardSeason.where(id: card_season_ids).in_order_of(:id, card_season_ids).pluck(:card_id)

  def detail_paths(card_season_ids)
    slugs = Catalog::CardSeason.where(id: card_season_ids).joins(:card).pluck(:id, "catalog_cards.slug").to_h
    card_season_ids.map { "/en/cards/#{slugs.fetch(it)}/seasons/#{@season.number}" }
  end

  def goal_tiles = css_select(".set-entry > section#goals ol.goal-tiles > li > .goal-tile")

  # The tiles as [ bookmark, name, kind, "held/total" ].
  def goal_tile_rows
    goal_tiles.map do |tile|
      link = tile.at_css("> a.goal-tile__link")
      [ link.at_css("> .goal-bookmark").text, link.at_css(".goal-tile__name b").text, link.at_css(".goal-tile__kind").text, link.at_css(".goal-tile__count").text ]
    end
  end

  def thumbs(tile) = tile.css("> ul.goal-tile__missing > li.goal-tile__thumb > a.card-link")

  def suggestions = css_select("#goals ul.goal-suggestions > li > .goal-suggestion")

  def in_progress_groups
    get library_in_progress_path(locale: :en), headers: { "Turbo-Frame" => "set-entry-in-progress" }
    css_select("#set-entry-in-progress-title ~ section.set-entry__group").map do |group|
      [ group.at_css("> h3").text, group.css("a.set-tile").map { it.at_css(".set-tile__name").text } ]
    end
  end

  def count_queries(&request)
    ActiveRecord::Base.connection.clear_query_cache
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &request)
    queries
  end

  test "OBJECTIFS leads the entry with a tile per goal in number order, each linking its album, its missing cards opening their detail" do
    roguelike = theme("roguelike", 12)
    theme("horror", 10)
    halo = named("franchise", "Halo", 4)
    hold_all(@player, roguelike.first(3) + halo.first(1))
    add(kind: "theme", key: "roguelike")
    add(kind: "theme", key: "horror")
    add(kind: "franchise", key: "halo")
    Game::RemoveGoal.new.call(player: @player, kind: "theme", key: "horror").value!
    sign_in(@player)

    get library_path(locale: :en)

    assert_response :success
    assert_equal [ "Goals", "Find a set", "My sets" ], css_select(".set-entry h2").map(&:text)
    assert_select ".set-entry > section#goals:first-child + section.set-search"
    assert_select "#goals .goals__count", "2 / 5"
    assert_equal [ [ "1", "Roguelike", "Theme", "3/12" ], [ "3", "Halo", "Franchise", "1/4" ] ], goal_tile_rows
    assert_equal [ "goal-tone--1", "goal-tone--3" ], goal_tiles.map { it["class"][/goal-tone--\d/] }
    assert_equal [ "/en/library/theme/roguelike", "/en/library/franchise/halo" ], goal_tiles.map { it.at_css("> a.goal-tile__link")["href"] }
    assert_match(/\AGoal 1: Roguelike, theme, 3 cards out of 12, 3 more for gold\z/i, goal_tiles.first.at_css("a.goal-tile__link > .visually-hidden").text)
    assert_equal "Only 3 more for Gold", goal_tiles.first.at_css(".goal-tile__next").text.squish
    assert_equal 3, goal_tiles.first.css(".goal-tile__track .set-row__tick").size
    assert_empty goal_tiles.last.css(".set-row__tick")

    roguelike_thumbs = thumbs(goal_tiles.first)
    assert_equal detail_paths(roguelike[3, 5]), roguelike_thumbs.map { it["href"] }
    assert roguelike_thumbs.all? { it.at_css("> .card.card--s.card--not-owned") }
    assert_match(/, not owned\z/, roguelike_thumbs.first["aria-label"])
    assert_equal "Cards missing from Roguelike", goal_tiles.first.at_css("> ul.goal-tile__missing")["aria-label"]
    more = goal_tiles.first.at_css("li.goal-tile__thumb > a.goal-tile__more")
    assert_equal [ "+4", "4 more missing cards, in the album of Roguelike", "/en/library/theme/roguelike?state%5B%5D=missing" ],
      [ more.text.squish, more["aria-label"], more["href"] ]
    assert_equal detail_paths(halo.drop(1)), thumbs(goal_tiles.last).map { it["href"] }
    assert_select goal_tiles.last, "a.goal-tile__more", false

    assert_equal "3 free goals · mark a set from its album", css_select("#goals p.goals__free > span:last-child").sole.text
    assert_select "#goals .goal-suggestions, #goals .goals__empty, #goals .goal-row", false
    assert_select "#goals a.goal-tile__link a, #goals [style]", false
  end

  test "a goal missing thirty cards shows five of them, then +25 to its album filtered on the missing cards" do
    big = theme("big", 35)
    hold_all(@player, big.first(5))
    add(kind: "theme", key: "big")
    sign_in(@player)

    get library_path(locale: :fr)

    tile = goal_tiles.sole
    assert_equal 5, thumbs(tile).size
    assert_equal detail_paths(big[5, 5]).map { it.sub("/en/", "/fr/") }, thumbs(tile).map { it["href"] }
    more = tile.at_css("a.goal-tile__more")
    assert_equal [ "+25", "25 autres cartes manquantes, dans l'album de Big", "/fr/library/theme/big?state%5B%5D=missing" ],
      [ more.text.squish, more["aria-label"], more["href"] ]
  end

  test "a custom set goal is a tile of owned over total with no ticks, its missing games as thumbnails, a game with no published edition counted in +N" do
    members = take(4)
    custom_set = create_custom_set(@player, name: "Mes favoris", card_ids: card_ids(members))
    hold_all(@player, members.first(1))
    Catalog::CardSeason.where(id: members[1]).update_all(rarity: nil)
    add(custom_set: custom_set.token)
    sign_in(@player)

    get library_path(locale: :en)

    assert_equal [ [ "1", "Mes favoris", "Custom set", "1/4" ] ], goal_tile_rows
    tile = goal_tiles.sole
    assert_equal "/en/library/custom-sets/#{custom_set.token}", tile.at_css("a.goal-tile__link")["href"]
    assert_select tile, ".set-row__tick", false
    assert_equal detail_paths(members.drop(2)), thumbs(tile).map { it["href"] }
    assert_equal "+1", tile.at_css("a.goal-tile__more").text.squish
  end

  test "with no goal, OBJECTIFS suggests the three started sets fewest cards from complete, each one tap from being a goal" do
    far = theme("far", 12)
    near = theme("near", 12)
    halo = named("franchise", "Halo", 4)
    supergiant = named("studio", "Supergiant", 3)
    done = named("franchise", "Done", 2)
    theme("untouched", 5)
    hold_all(@player, far.first(2) + near.first(10) + halo.first(3) + supergiant.first(1) + done)
    sign_in(@player)

    get library_path(locale: :en)

    assert_select "#goals .goals__count", "0 / 5"
    assert_select "#goals .goal-tiles, #goals .goals__free", false
    assert_equal "No goal yet. The sets you are closest to completing:", css_select("#goals p.goals__empty--suggesting > span:last-child").sole.text
    assert_equal [ [ "Halo", "Franchise", "3/4", "1 card left to complete" ], [ "Near", "Theme", "10/12", "2 cards left to complete" ],
      [ "Supergiant", "Studio", "1/3", "2 cards left to complete" ] ],
      suggestions.map { [ it.at_css(".goal-suggestion__name b").text, it.at_css(".goal-suggestion__kind").text, it.at_css(".goal-suggestion__count").text,
        it.at_css(".goal-suggestion__left").text ] }
    assert_equal [ "/en/library/franchise/halo", "/en/library/theme/near", "/en/library/studio/supergiant" ], suggestions.map { it.at_css("a.goal-suggestion__link")["href"] }
    assert_equal "Halo, franchise, 3 cards out of 4, 1 card left to complete", suggestions.first.at_css("a.goal-suggestion__link > .visually-hidden").text

    form = suggestions.first.at_css("form.button-form")
    assert_equal [ "/en/library/goals", "post" ], [ form["action"], form["method"] ]
    assert_equal({ "kind" => "franchise", "key" => "halo", "from" => "sets" }, form.css("input[type=hidden]:not([name=authenticity_token])").to_h { [ it["name"], it["value"] ] })
    button = form.at_css("button.goal-suggestion__button")
    assert_equal [ "Mark as goal", "Mark as goal: Halo" ], [ button.text.squish, button["aria-label"] ]
    assert_select "#goals [style]", false
  end

  test "with neither a goal nor a started set, OBJECTIFS keeps its empty line" do
    theme("untouched", 5)
    sign_in(@player)

    get library_path(locale: :fr)

    assert_select "#goals p.goals__empty:not(.goals__empty--suggesting)", "Aucun objectif. Ouvrez l'album d'un set et marquez-le comme objectif."
    assert_select "#goals .goal-suggestions, #goals .goal-tiles", false
  end

  test "EN COURS groups its sets by kind, the goal sets left out; a search keeps OBJECTIFS above its results" do
    roguelike = theme("roguelike", 12)
    horror = theme("horror", 10)
    supergiant = named("studio", "Supergiant", 5)
    hold_all(@player, roguelike.first(3) + horror.first(4) + supergiant.first(3))
    add(kind: "theme", key: "horror")
    sign_in(@player)

    assert_equal [ [ "Themes", [ "Roguelike" ] ], [ "Studios", [ "Supergiant" ] ] ], in_progress_groups
    assert_select "a.set-tile[href='/en/library/theme/horror']", false
    # Horror, one card from gold, is the closest; the frame goes to Supergiant, two from complete.
    assert_equal [ "Supergiant" ], css_select("a.set-tile--closest").map { it.at_css(".set-tile__name").text }

    add(kind: "theme", key: "roguelike")
    add(kind: "studio", key: "supergiant")
    assert_empty in_progress_groups
    assert_select "#set-entry-in-progress-title", false
    assert_select "turbo-frame#set-entry-in-progress > p.set-entry__empty", "No other set in progress. Find one above."
    Game::Goal.where(player_id: @player.id, set_key: %w[roguelike supergiant]).delete_all

    get library_path(locale: :en, q: "horror")

    assert_equal [ "Goals", "Find a set", "Results", "My sets" ], css_select(".set-entry h2").map(&:text)
    assert_equal [ [ "1", "Horror", "Theme", "4/10" ] ], goal_tile_rows
    assert_select "#set-results-title ~ ul.set-tiles a.set-tile.set-tile--goal.goal-tone--1[href='/en/library/theme/horror']"
  end

  test "a player whose only goal is not started yet, with nothing in progress, reads that no other set is in progress" do
    theme("roguelike", 12)
    add(kind: "theme", key: "roguelike")
    sign_in(@player)

    assert_empty in_progress_groups
    assert_select "turbo-frame#set-entry-in-progress > p.set-entry__empty", "No other set in progress. Find one above."
  end

  test "no database id reaches OBJECTIFS, and its GET writes nothing" do
    roguelike = theme("roguelike", 12)
    members = take(3)
    custom_set = create_custom_set(@player, card_ids: card_ids(members))
    hold_all(@player, roguelike.first(3))
    add(kind: "theme", key: "roguelike")
    add(custom_set: custom_set.token)
    sign_in(@player)
    ids = Catalog::Set.where(season_id: @season.id).ids + Catalog::CardSeason.where(season_id: @season.id).ids + Catalog::Card.ids +
      Game::Goal.where(player_id: @player.id).ids + [ custom_set.id ]

    assert_no_changes -> { [ Game::Goal.count, Game::SetTier.count, Game::PlayerState.find_by!(player_id: @player.id).attributes ] } do
      get library_path(locale: :en)
    end

    assert_select "#goals [data-id]", false
    named = css_select("#goals *").flat_map do |node|
      node.attributes.select { |name, _| name.in?(%w[id href action name for aria-label aria-labelledby]) || (name.start_with?("data-") && !name.start_with?("data-tier-at", "data-card-art")) }
        .values.map(&:value)
    end
    named = named.map { it.gsub(%r{board-\d+-\d+|/seasons/\d+|Seed \d+|season \d+|\b(19|20)\d\d\b|\d+ (more|cards?) |out of \d+|Goal \d+}, "") }
    ids.uniq.each { |id| assert_no_match(/(?<![\w.-])#{id}(?![\w.])/, named.join(" "), "id #{id}") }
  end

  test "OBJECTIFS costs the same queries with one goal or five, three sets started or forty; so do its suggestions" do
    sets = (1..45).map { theme("theme-#{it}", 12) }
    hold_all(@player, sets.first(3).flat_map { it.first(2) })
    sign_in(@player)

    suggested_three = count_queries { get library_path(locale: :en) }
    assert_equal 3, suggestions.size
    hold_all(@player, sets[3, 37].flat_map { it.first(2) })
    suggested_forty = count_queries { get library_path(locale: :en) }
    assert_equal suggested_three, suggested_forty

    add(kind: "theme", key: "theme-1")
    one = count_queries { get library_path(locale: :en) }
    assert_equal 1, goal_tiles.size
    (2..5).each { add(kind: "theme", key: "theme-#{it}") }
    five = count_queries { get library_path(locale: :en) }
    assert_equal 5, goal_tiles.size
    assert_equal one, five
    assert_equal [ 5 ] * 5, goal_tiles.map { thumbs(it).size }
  end
end
