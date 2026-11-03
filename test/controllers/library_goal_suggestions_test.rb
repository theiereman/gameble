require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

# OBJECTIFS at the head of the collection entry: with no goal, the three
# started sets closest to complete, each one tap from being a goal. EN COURS
# leaves the goal sets out.
class LibraryGoalSuggestionsTest < ActionDispatch::IntegrationTest
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

  def goal_rows = css_select(".set-entry > section#goals ol.goals__list > li > a.goal-row")

  # The rows as [ bookmark, name, kind, "held/total" ].
  def goal_row_texts
    goal_rows.map { |row| [ row.at_css("> .goal-bookmark").text, row.at_css(".goal-row__name b").text, row.at_css(".goal-row__kind").text, row.at_css(".goal-row__count").text ] }
  end

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
    assert_select "#goals .goals__list, #goals .goals__free", false
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
    assert_select "#goals .goal-suggestions, #goals .goals__list", false
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
    assert_equal [ [ "1", "Horror", "Theme", "4/10" ] ], goal_row_texts
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
    assert_equal 1, goal_rows.size
    (2..5).each { add(kind: "theme", key: "theme-#{it}") }
    five = count_queries { get library_path(locale: :en) }
    assert_equal 5, goal_rows.size
    assert_equal one, five
  end
end
