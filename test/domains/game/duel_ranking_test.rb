require "test_helper"

# Game::DuelRanking: midrank percentiles of one group, exact and rounded half up to one decimal, and each value's distance
# from the group's median.
class Game::DuelRankingTest < ActiveSupport::TestCase
  def places(keys, measures = keys)
    Game::DuelRanking.new(keys.each_index.map { [ it, keys[it], measures[it] ] }).places
  end

  test "equal keys share the midrank, the entry itself counted half" do
    assert_equal [ 12.5, 50.0, 50.0, 87.5 ], places([ 10, 20, 20, 40 ]).values.map { it.percentile.to_f }
  end

  test "a lone entry sits at 50" do
    assert_equal BigDecimal("50"), places([ 7 ]).fetch(0).percentile
  end

  test "a percentile is exact before its rounding half up to one decimal" do
    assert_equal %w[16.7 50.0 83.3], places([ 1, 2, 3 ]).values.map { it.percentile.to_s("F") }
    assert_equal %w[6.3 18.8 31.3 43.8 56.3 68.8 81.3 93.8], places((1..8).to_a).values.map { it.percentile.to_s("F") }
  end

  test "keys compared as tuples break a tie on their second member" do
    assert_equal [ 75.0, 25.0 ], places([ [ 91, 100 ], [ 91, 50 ] ], [ 91, 91 ]).values.map { it.percentile.to_f }
  end

  test "the distance from the median, the mean of the two middle values for an even count" do
    assert_equal [ 10.0, 0.0, 20.0 ], places([ 10, 20, 40 ]).values.map(&:median_distance)
    assert_equal [ 15.0, 5.0, 5.0, 25.0 ], places([ 10, 20, 30, 50 ]).values.map(&:median_distance)
  end

  test "an empty group has no places" do
    assert_empty places([])
  end
end
