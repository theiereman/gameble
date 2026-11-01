require "test_helper"
require_relative "../../support/game_sets"
require_relative "../../support/custom_sets"
require_relative "../../support/holdings"

# A player's goals read at once, in number order: each one's set, its games,
# those held and its tiers; or their targets alone.
class Game::GoalNeedsTest < ActiveSupport::TestCase
  include GameSets
  include CustomSets
  include Holdings

  setup do
    @player = accounts_players(:player)
  end

  def add(**aim) = Game::AddGoal.new.call(player: @player, **aim).value!

  test "reads each goal in number order with its games, those held, and its tiers" do
    members = [ catalog_card_seasons(:common_card_one).id, *unheld_cards(4) ]
    insert_set(members, { novice: 3, complete: 5 }, key: "roguelike", params: { "theme" => "roguelike" })
    custom_set = create_custom_set(@player, card_ids: fixture_card_ids.first(3))
    hold(@player, catalog_card_seasons(:common_card_one).id)
    hold(@player, catalog_card_seasons(:uncommon_card_one).id)
    add(kind: "theme", key: "roguelike")
    add(custom_set: custom_set.token)
    add(kind: "studio", key: "valve")
    Game::RemoveGoal.new.call(player: @player, kind: "theme", key: "roguelike").value!
    add(kind: "theme", key: "roguelike")

    needs = Game::GoalNeeds.call(@player)
    roguelike, favourites, valve = needs

    assert_equal [ 1, 2, 3 ], needs.map(&:position)
    assert_equal [ "theme", "roguelike", false ], [ roguelike.kind, roguelike.key, roguelike.custom? ]
    assert_equal Catalog::CardSeason.where(id: members).order(:id).pluck(:card_id).sort, roguelike.card_ids.sort
    assert_equal [ catalog_cards(:common_card).id ], roguelike.held_card_ids
    assert_equal [ 1, 5, false ], [ roguelike.held, roguelike.total, roguelike.complete? ]
    assert_equal roguelike.card_ids - [ catalog_cards(:common_card).id ], roguelike.missing_card_ids
    assert_equal [ "novice", 2 ], roguelike.to_set_standing.then { [ it.next_tier, it.missing ] }

    assert favourites.custom?
    assert_equal [ custom_set.token, "Mes favoris", 2, 3 ], [ favourites.custom_set_token, favourites.custom_set_name, favourites.held, favourites.total ]
    assert_equal [ "complete", 1 ], favourites.to_set_standing.then { [ it.next_tier, it.missing ] }

    assert_equal [ "studio", "valve", 0, 1 ], [ valve.kind, valve.key, valve.held, valve.total ]
  end

  test "the targets alone name each goal by its set, a custom set by its token and name" do
    custom_set = create_custom_set(@player)
    add(kind: "studio", key: "valve")
    add(custom_set: custom_set.token)

    valve, favourites = Game::GoalNeeds.targets(@player)

    assert_equal [ 1, "studio", "valve", catalog_sets(:valve_one) ], [ valve.position, valve.kind, valve.key, valve.set ]
    assert valve.aims_at?(kind: "studio", key: "valve")
    assert_not valve.aims_at?(custom_set: custom_set.token)
    assert_equal [ 2, custom_set.token, "Mes favoris", nil ], [ favourites.position, favourites.custom_set_token, favourites.custom_set_name, favourites.set ]
    assert favourites.aims_at?(custom_set: custom_set.token)
  end

  test "a player without goals, or no player, has none, read in one query" do
    assert_queries_count(1) { assert_equal [], Game::GoalNeeds.call(@player) }
    assert_queries_count(0) { assert_equal [], Game::GoalNeeds.targets(nil) }
  end
end
