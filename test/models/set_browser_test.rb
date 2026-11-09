require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"

# SetBrowser: every set of the season and the player's own sets, filtered by
# kind, state, tier reached and goals (OR within a group, AND across groups),
# searched over name and kind, in the order the All sets screen shows them.
class SetBrowserTest < ActiveSupport::TestCase
  include CatalogSeeds
  include CustomSets
  include GameSets

  setup do
    @player = accounts_players(:player)
    @season, @cards = published_cards(400)
  end

  def take(count) = @cards.shift(count)

  def theme(key, size) = take(size).tap { insert_ranked_theme(it, key:, season: @season) }

  def named(kind, name, size) = take(size).tap { insert_set(it, { complete: size }, kind:, key: name.parameterize, params: { kind => name }, season: @season) }

  def card_ids(card_season_ids) = Catalog::CardSeason.where(id: card_season_ids).in_order_of(:id, card_season_ids).pluck(:card_id)

  def own_set(name, members) = create_custom_set(@player, name:, card_ids: card_ids(members))

  def browser(season: @season, marks: GoalMarks::NONE, **filters)
    own_sets = Game::CustomSetStandings.call(@player).to_h { [ it, it.custom? ? it.name : "My Steam library" ] }
    SetBrowser.new(season:, player: @player, own_sets:, goals: marks, filters:)
  end

  def names(**filters)
    I18n.with_locale(:en) { browser(**filters).entries.map { it.own? ? it.own_set.name || "My Steam library" : SetLabel.for(it.set) } }
  end

  def add_goal(**aim) = Game::AddGoal.new.call(player: @player, **aim).value!

  def goal_marks = GoalMarks.new(Game::GoalNeeds.call(@player))

  test "the default list: in progress closest first, then not started by name, then complete, nothing capped" do
    far = theme("far", 40)
    near = theme("near", 40)
    theme("pirates", 40)
    theme("horror", 40)
    done = named("franchise", "Done", 3)
    extra = (1..60).map { theme("extra-#{it}", 3) }
    hold_all(@player, far.first(5) + near.first(28) + done)

    assert_equal [ "Near", "Far" ], names.first(2)
    assert_equal "Done", names.last
    assert_equal 65, names.size
    assert_equal extra.size + 2, names[2..-2].size
    assert_equal %w[Horror Pirates], names[2..-2].select { %w[Horror Pirates].include?(it) }
  end

  test "a set held by one card is in progress; a set without cards held is not started" do
    touched = theme("touched", 40)
    theme("untouched", 40)
    hold_all(@player, touched.first(1))

    assert_equal [ "Touched" ], names(state: [ "in_progress" ])
    assert_equal [ "Untouched" ], names(state: [ "not_started" ])
    assert_empty names(state: [ "complete" ])
  end

  test "the state group keeps its states, OR within the group" do
    done = named("franchise", "Done", 3)
    started = named("franchise", "Started", 3)
    named("franchise", "Fresh", 3)
    hold_all(@player, done + started.first(2))

    assert_equal [ "Done" ], names(state: [ "complete" ])
    assert_equal [ "Started", "Done" ], names(state: %w[complete in_progress])
  end

  test "the kind group: the season's kinds, then My sets when the player has one; OR within the group, AND across groups" do
    named("franchise", "Halo", 3)
    named("studio", "Valve", 3)
    theme("horror", 3)
    assert_equal %w[theme franchise studio], browser.kinds

    custom = take(3)
    own_set("Favourites", custom)
    hold_all(@player, custom.first(1))
    assert_equal %w[theme franchise studio mine], browser.kinds

    assert_equal [ "Halo" ], names(kind: [ "franchise" ])
    assert_equal [ "Favourites" ], names(kind: [ "mine" ])
    assert_equal [ "Halo", "Valve" ], names(kind: %w[franchise studio])
    assert_empty names(kind: [ "franchise" ], state: [ "complete" ])
    assert_equal [ "Favourites" ], names(kind: %w[mine franchise], state: [ "in_progress" ])
  end

  test "a tier chosen keeps the sets at that rank, leaves out the custom sets, and a set past it is at its own rank" do
    adept = theme("adept", 40)
    expert = theme("expert", 40)
    small = theme("small", 3)
    done = named("franchise", "Done", 3)
    custom = take(3)
    own_set("Favourites", custom)
    hold_all(@player, adept.first(12) + expert.first(22) + small.first(2) + done + custom)

    assert_equal [ "Adept" ], names(tier: [ "adept" ])
    assert_equal [ "Expert" ], names(tier: [ "expert" ])
    assert_equal [ "Expert", "Adept" ], names(tier: %w[adept expert])
    assert_empty names(tier: [ "master" ])
    assert_empty names(tier: [ "novice" ], kind: [ "mine" ])
  end

  test "the goals group keeps the sets chosen, game and custom, others out" do
    theme("horror", 3)
    theme("roguelike", 3)
    custom = take(3)
    favourites = own_set("Favourites", custom)
    add_goal(kind: "theme", key: "horror")
    add_goal(custom_set: favourites.token)
    marks = goal_marks

    assert_equal [ "Horror" ], names(marks:, goals: [ "theme:horror" ])
    assert_equal [ "Favourites", "Horror" ], names(marks:, goals: [ "theme:horror", favourites.token ])
    assert_equal 3, names(marks:).size
    assert_equal [ "Horror" ], names(marks:, goals: [ "theme:horror" ], kind: [ "theme" ])
    assert_empty names(marks:, goals: [ "theme:horror" ], state: [ "complete" ])
    assert_equal 3, names(goals: [ "theme:horror" ]).size
  end

  test "the search matches a name or a kind, name-prefix first, accents and case ignored, combined with filters" do
    halo = named("franchise", "Halo", 3)
    named("studio", "Half Life Studio", 3)
    named("franchise", "Portal", 3)
    hold_all(@player, halo.first(2))

    assert_equal [ "Half Life Studio", "Halo" ], names(q: "HAL")
    assert_equal [ "Halo", "Portal" ], names(q: "franchise")
    assert_equal [ "Halo" ], names(q: "hál", state: [ "in_progress" ])
    assert_empty names(q: "nothing matches")
  end

  test "an over-long search is truncated, a non-string search and unknown filter values ignored, never an error" do
    theme("horror", 3)

    assert_equal SetSearch::MAX_QUERY, browser(q: "a" * 300).query.size
    assert_equal "", browser(q: { "x" => "y" }).query
    assert_equal names, names(state: "foo")
    assert_equal names, names(state: %w[foo bar], tier: [ "bronze" ], kind: [ "nope" ], goals: [ "theme:gone" ])
    assert_equal names, names(state: [ { "x" => "y" } ])
  end

  test "a kind asked that the season does not hold is ignored; no season holds nothing" do
    theme("horror", 3)

    assert_equal names, names(kind: [ "studio" ])
    assert_empty browser(season: nil).entries
  end
end
