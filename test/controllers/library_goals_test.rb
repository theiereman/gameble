require "test_helper"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

# The player's goals in the collection: OBJECTIFS at the head of their own
# entry, one tile per goal in number order, then the free slot or the empty
# line; the goal button in the header of their own album of a game set or a
# custom set, never elsewhere. A public profile shows only the game set goals,
# without their bookmark.
class LibraryGoalsTest < ActionDispatch::IntegrationTest
  include CustomSets
  include GameSets
  include LibraryRequests
  include SteamSignIn

  def sign_in_origin = "/fr"

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one).id
  end

  def add(player = @player, **aim) = Game::AddGoal.new.call(player:, **aim).value!

  def roguelike = insert_set([ @common, *unheld_cards(4) ], { novice: 3, complete: 5 }, key: "roguelike", params: { "theme" => "roguelike" })

  def links = css_select("#goals .goal-tile > a.goal-tile__link")

  def count_queries(&request)
    ActiveRecord::Base.connection.clear_query_cache
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &request)
    queries
  end

  test "OBJECTIFS leads the entry with the goals in number order, each tile's link to its album named by its sentence, then the free slot" do
    roguelike
    custom_set = create_custom_set(@player)
    hold(@player, @common)
    add(kind: "studio", key: "valve")
    add(kind: "theme", key: "roguelike")
    add(custom_set: custom_set.token)
    Game::RemoveGoal.new.call(player: @player, kind: "studio", key: "valve").value!
    sign_in(@player)

    get library_path(locale: :fr)

    assert_select ".set-entry > section#goals.goals[aria-labelledby=goals-title]:first-child + section.set-search + turbo-frame#set-search-results + section.custom-sets"
    assert_select "#goals h2#goals-title", "Objectifs"
    assert_select "#goals .goals__count", "2 / 5"
    assert_select "#goals .goals__panel.panel--brackets"
    assert_equal [ "/fr/library/theme/roguelike", "/fr/library/custom-sets/#{custom_set.token}" ], links.map { it["href"] }
    assert_equal %w[goal-tone--2 goal-tone--3], css_select("#goals .goal-tile").map { it["class"][/goal-tone--\d/] }

    theme, favourites = links
    assert_equal "Objectif 2\u202F: Roguelike, thème, 1 carte sur 5, plus que 2 pour Novice", theme.at_css(".visually-hidden").text
    assert_equal "Objectif 3\u202F: Mes favoris, set perso, 1 carte sur 3, plus que 2 pour le set complet", favourites.at_css(".visually-hidden").text
    assert_equal [ "2", "Roguelike", "Thème", "1/5", "Plus que 2 pour Novice" ],
      [ ".goal-bookmark", ".goal-tile__name b", ".goal-tile__kind", ".goal-tile__count", ".goal-tile__next" ].map { theme.at_css(it).text.squish }
    assert_equal [ "Set perso", "Plus que 2 pour Complet" ], [ ".goal-tile__kind", ".goal-tile__next" ].map { favourites.at_css(it).text.squish }
    assert_equal %w[1 5], theme.css("progress.goal-tile__bar").then { [ it.attr("value").value, it.attr("max").value ] }
    assert_equal [ "novice" ], theme.css(".set-row__tick").map { it["class"][/--(\w+)/, 1] }
    theme.element_children.reject { it.classes.include?("visually-hidden") }.each { assert_equal "true", it["aria-hidden"], it.to_html }

    assert_select "#goals .goals__free > span:not(.goal-bookmark)", "3 objectifs libres · marquez un set depuis son album"
    assert_select "#goals .goals__free .goal-bookmark.goal-bookmark--hollow[aria-hidden=true]", "1"
    assert_select "[style]", false
  end

  test "with no goal, OBJECTIFS shows 0 / 5, the hollow bookmark and the empty line; with five, no free slot" do
    sign_in(@player)

    get library_path(locale: :en)

    assert_select "#goals .goals__count", "0 / 5"
    assert_select "#goals .goals__empty > span:not(.goal-bookmark)", "No goal. Open a set's album and mark it as a goal."
    assert_select "#goals .goals__empty .goal-bookmark--hollow", ""
    assert_select "#goals .goal-tile, #goals .goal-suggestion, #goals .goals__free", false

    %w[a1 a2 a3 a4 a5].each { insert_set(unheld_cards(3), { complete: 3 }, key: it, params: { "theme" => it }) && add(kind: "theme", key: it) }
    get library_path(locale: :en)

    assert_equal 5, links.size
    assert_select "#goals .goals__free, #goals .goals__empty", false
  end

  test "the entry costs the same queries with two goals or five" do
    %w[a1 a2 a3].each { insert_set(unheld_cards(3), { complete: 3 }, key: it, params: { "theme" => it }) }
    add(kind: "theme", key: "a1")
    add(custom_set: create_custom_set(@player).token)
    sign_in(@player)
    two = count_queries { get library_path(locale: :en) }

    add(kind: "theme", key: "a2")
    add(kind: "studio", key: "valve")
    add(custom_set: create_custom_set(@player, name: "Autre").token)

    assert_equal 5, Game::Goal.where(player_id: @player.id).count
    assert_equal two, count_queries { get library_path(locale: :en) }
  end

  test "the album of a game set holds the goal button, marked in the goal's colour once a goal" do
    roguelike
    sign_in(@player)

    get library_set_path(locale: :fr, kind: "theme", key: "roguelike")
    assert_select ".set-album__header .set-album__actions #set-album-goal:not(.goal-control--set) form[action='/fr/library/goals'][method=post]" do
      assert_select "input[name=kind][value=theme]"
      assert_select "input[name=key][value=roguelike]"
      assert_select "button.goal-button", "Marquer comme objectif"
    end

    add(kind: "studio", key: "valve")
    add(kind: "theme", key: "roguelike")
    get library_set_path(locale: :fr, kind: "theme", key: "roguelike")
    assert_select "#set-album-goal.goal-control--set.goal-tone--2 button.goal-button[aria-label='Objectif 2, Roguelike. Retirer des objectifs']",
      /Objectif 2 · Retirer/
    assert_select "#set-album-goal input[name=_method][value=delete]"
  end

  test "a complete set's album offers no goal button" do
    hold(@player, catalog_card_seasons(:portal_one).id)
    sign_in(@player)

    get library_set_path(locale: :en, kind: "studio", key: "valve")

    assert_select "#set-album-goal button", false
  end

  test "a custom set's album holds the goal button beside its own, and the Steam library set's holds it too" do
    custom_set = create_custom_set(@player)
    library = Game::CustomSet.create!(player_id: @player.id, kind: Game::CustomSet::STEAM_LIBRARY)
    Game::CustomSetGame.create!(custom_set_id: library.id, card_id: catalog_cards(:portal).id)
    sign_in(@player)

    get custom_set_path(locale: :fr, token: custom_set.token)
    assert_select ".set-album__actions > #set-album-goal + .button", "Modifier"
    assert_select "#set-album-goal input[name=custom_set][value='#{custom_set.token}']"

    get custom_set_path(locale: :fr, token: library.token)
    assert_select "#set-album-goal input[name=custom_set][value='#{library.token}']"
  end

  test "another player's album of the same set and the hub show no goal; a public profile no bookmark nor custom set goal" do
    add(custom_set: create_custom_set(@player).token)
    add(kind: "studio", key: "valve")
    sign_in(@player)

    get brother_set_path(locale: :en, token: @player.token, kind: "studio", key: "valve")
    assert_response :success
    assert_select "#set-album-goal, .goal-bookmark, .goal-control", false

    get brother_path(locale: :en, token: @player.token)
    assert_select "#goals, .goal-bookmark", false
    assert_select ".goal-row", 1
    assert_not_includes response.body, "Mes favoris"

    get home_path(locale: :en)
    assert_select "#goals, .goal-bookmark, .goal-row", false
  end
end
