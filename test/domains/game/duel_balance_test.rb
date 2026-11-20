require "test_helper"
require_relative "../../support/balance_duels"

# How the finished duels of one rules version played: live duels with their deck recipes apart from practice duels by
# bot archetype, a forfeit counted as finished but in no rate.
class Game::DuelBalanceTest < ActiveSupport::TestCase
  include BalanceDuels

  def recipe_rows(report) = report.recipes.map { [ it.name, it.decks, it.wins ] }

  test "the live duels of the version, the forfeit counted as finished and nowhere else" do
    play_balance_duels

    report = Game::DuelBalance.call(Game::DuelRules::VERSION)
    live = report.live

    assert_equal Game::DuelRules::VERSION, report.rules_version
    assert_equal [ 4, 1, 3 ], [ live.finished, live.forfeited, live.played ]
    assert_equal [ 1, 1, 1 ], [ live.first_caller_wins, live.decided_on_margin, live.with_automatic_move ]
    assert_equal({ %i[rating high] => 2, %i[popularity low] => 1, %i[release high] => 1, %i[discovery low] => 1 }, live.stats_called)
    assert_equal [ [ "coverage", 1, 1 ], [ "popularity", 1, 0 ], [ "rating", 2, 1 ], [ "other", 2, 0 ] ], recipe_rows(report)
  end

  test "the duels of the previous rules count only under their own version" do
    play_balance_duels

    report = Game::DuelBalance.call(Game::DuelRules::VERSION - 1)

    assert_equal [ 1, 0, 1 ], [ report.live.finished, report.live.forfeited, report.live.first_caller_wins ]
    assert_equal [ [ "other", 2, 1 ] ], recipe_rows(report)
    assert_equal({ %i[rating low] => 1 }, report.live.stats_called)
    assert_equal 0, report.practice_total.finished
    assert_empty report.practice
  end

  test "practice duels group by bot archetype, an unknown archetype as other, and never feed the recipes" do
    play_balance_duels

    report = Game::DuelBalance.call(Game::DuelRules::VERSION)

    assert_equal [ [ "rating", 2, 1 ], [ "other", 1, 0 ] ], report.practice.map { [ it.archetype, it.figures.finished, it.bot_wins ] }
    assert_equal 3, report.practice_total.finished
    assert_equal({ %i[popularity high] => 2, %i[rating low] => 1 }, report.practice_total.stats_called)
    assert_not_includes report.recipes.map(&:name), "trumps"
  end

  test "a version with no finished duel reads empty" do
    report = Game::DuelBalance.call(Game::DuelRules::VERSION)

    assert_equal 0, report.live.finished
    assert_empty report.recipes
    assert_empty report.practice
    assert_empty report.live.stats_called
  end

  test "the versions are those of finished duels and the current one, newest first" do
    assert_equal [ Game::DuelRules::VERSION ], Game::DuelBalance.versions

    play_balance_duels

    assert_equal [ Game::DuelRules::VERSION, Game::DuelRules::VERSION - 1 ], Game::DuelBalance.versions
  end
end
