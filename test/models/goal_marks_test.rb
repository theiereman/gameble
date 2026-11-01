require "test_helper"

class GoalMarksTest < ActiveSupport::TestCase
  def target(position, kind: "theme", key: "roguelike", token: nil)
    Game::GoalNeeds::Target.new(goal_id: position * 10, position:, kind: (kind unless token), key: (key unless token),
      custom_set_token: token, custom_set_name: ("Mes favoris" if token), set: nil)
  end

  def need(target, card_ids) = Game::GoalNeeds::Need.new(target:, card_ids:, held_card_ids: [], tiers: {})

  def marks
    GoalMarks.new([ need(target(4, kind: "studio", key: "valve"), [ 1, 2 ]), need(target(1), [ 2, 3 ]), need(target(3, token: "tok"), [ 3 ]) ])
  end

  test "the numbers of a card's goals, in number order, owned or not; none for a card in no goal or without id" do
    assert_equal [ 1, 4 ], marks.numbers_for(2)
    assert_equal [ 4 ], marks.numbers_for(1)
    assert_equal [ 1, 3 ], marks.numbers_for(3)
    assert_equal [], marks.numbers_for(9)
    assert_equal [], marks.numbers_for(nil)
    assert_equal [ 1, 3, 4 ], marks.needs.map(&:position)
  end

  test "without a goal: its bookmarks go, the others stay; without none: unchanged" do
    all = marks
    shown = all.without(target(1))

    assert_equal [ 4 ], shown.numbers_for(2)
    assert_equal [ 3 ], shown.numbers_for(3)
    assert_same all, all.without(nil)
  end

  test "the chosen goals by their filter value, a game set's kind:key or a custom set's token; unknown values ignored" do
    assert_equal [ "theme:roguelike", "tok", "studio:valve" ], marks.needs.map { GoalMarks.filter_value(it) }

    chosen = marks.chosen([ "studio:valve", "tok", "theme:gone", "1", nil ])
    assert_equal [ 3, 4 ], chosen.map(&:position)
    assert_equal [ 3, 1, 2 ], marks.card_ids_of(chosen)
    assert_empty marks.chosen([])
  end

  test "no goals: nothing marked, nothing to choose" do
    assert_not GoalMarks::NONE.any?
    assert_equal [], GoalMarks::NONE.numbers_for(1)
    assert_empty GoalMarks::NONE.targets
  end
end
