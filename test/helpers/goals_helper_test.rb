require "test_helper"
require_relative "../support/custom_sets"

class GoalsHelperTest < ActionView::TestCase
  include CustomSets

  setup do
    @player = accounts_players(:player)
    [ { custom_set: create_library_set(@player).token }, { custom_set: create_custom_set(@player).token }, { kind: "studio", key: "valve" } ]
      .each { Game::AddGoal.new.call(player: @player, **it).value! }
  end

  def names(locale)
    I18n.with_locale(locale) do
      needs = Game::GoalNeeds.call(@player)
      [ needs.map { goal_set_name(it) }, goal_name(needs.first), goal_card_words(needs) ]
    end
  end

  test "a goal on the Steam library set is named after it in both languages; a custom set's and a game set's by their own names" do
    assert_equal [ [ "My Steam library", "Mes favoris", "Valve" ], "Goal 1: My Steam library",
      "goal 1: My Steam library, goal 2: Mes favoris, goal 3: Valve" ], names(:en)
    assert_equal [ [ "Ma bibliothèque Steam", "Mes favoris", "Valve" ], "Objectif 1\u202F: Ma bibliothèque Steam",
      "objectif 1\u202F: Ma bibliothèque Steam, objectif 2\u202F: Mes favoris, objectif 3\u202F: Valve" ], names(:fr)
  end

  test "the goal targets name the Steam library set too, as a reached goal's toast reads them" do
    I18n.with_locale(:en) { assert_equal "My Steam library", goal_set_name(Game::GoalNeeds.targets(@player).first) }
  end
end
