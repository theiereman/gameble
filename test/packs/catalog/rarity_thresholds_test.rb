require "test_helper"

# Catalog::RarityThresholds (CAP-3): the shares and the cut of a season's
# prestige scores into the five tiers.
class Catalog::RarityThresholdsTest < ActiveSupport::TestCase
  def tier_counts(scores)
    tiers = Catalog::RarityThresholds.tiers(scores)
    tiers && [ 5, 4, 3, 2, 1 ].map { |tier| tiers.count(tier) }
  end

  def distinct(count)
    Array.new(count) { |index| (count - index).to_f }
  end

  test "the shares are keyed by the non-steel tiers and leave steel some cards" do
    assert_equal [ 2, 3, 4, 5 ], Catalog::RarityThresholds::SHARES.keys.sort
    assert_operator Catalog::RarityThresholds::SHARES.values.sum, :<, 10_000
    assert_equal 1, Catalog::RarityThresholds::STEEL
  end

  test "1,000 distinct scores cut into 10 / 40 / 100 / 250 / 600" do
    assert_equal [ 10, 40, 100, 250, 600 ], tier_counts(distinct(1_000))
  end

  test "150 distinct scores cut into 2 / 6 / 15 / 37 / 90" do
    assert_equal [ 2, 6, 15, 37, 90 ], tier_counts(distinct(150))
  end

  test "the order of the scores does not matter, and each card gets its own tier" do
    scores = distinct(1_000).shuffle(random: Random.new(42))
    tiers = Catalog::RarityThresholds.tiers(scores)

    assert_equal [ 10, 40, 100, 250, 600 ], [ 5, 4, 3, 2, 1 ].map { |tier| tiers.count(tier) }
    assert_equal 5, tiers[scores.index(1_000.0)]
    assert_equal 5, tiers[scores.index(991.0)]
    assert_equal 4, tiers[scores.index(990.0)]
    assert_equal 1, tiers[scores.index(600.0)]
    assert_equal 2, tiers[scores.index(601.0)]
  end

  test "equal scores share a tier" do
    scores = [ 100.0, 100.0, 100.0 ] + distinct(97)

    assert_equal [ 3, 2, 10, 25, 60 ], tier_counts(scores)
  end

  test "a score covering the gold and amethyst cuts leaves a tier empty" do
    scores = Array.new(5, 100.0) + distinct(95)

    assert_nil Catalog::RarityThresholds.tiers(scores)
  end

  test "20 distinct scores are too few" do
    assert_nil Catalog::RarityThresholds.tiers(distinct(20))
  end

  test "21 distinct scores is the smallest season with no empty tier" do
    assert_equal [ 1, 1, 2, 5, 12 ], tier_counts(distinct(21))
  end

  test "equal scores all the way down leave steel empty" do
    assert_nil Catalog::RarityThresholds.tiers(distinct(20) + Array.new(80, 0.0))
  end

  test "no score to cut" do
    assert_nil Catalog::RarityThresholds.tiers([])
    assert_raises(ArgumentError) { Catalog::RarityThresholds.thresholds([]) }
  end
end
