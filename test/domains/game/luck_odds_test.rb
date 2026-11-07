require "test_helper"

class Game::LuckOddsTest < ActiveSupport::TestCase
  test "a card scores by rarity: nothing for a Common, a hundred for a Legendary" do
    assert_equal [ 0, 1, 5, 20, 100 ], (1..5).map { Game::LuckOdds.points(it) }
  end

  test "a standard pack and a daily bonus pack promise the points of their independent cards" do
    regular = Game::LuckOdds.of(:regular)
    bonus = Game::LuckOdds.of("bonus")

    assert_in_delta 2.925, regular.points, 1e-9
    assert_in_delta 42.613875, regular.variance, 1e-9
    assert_in_delta 11.7, bonus.points, 1e-9
    assert_in_delta 334.47, bonus.variance, 1e-9
  end

  test "a reward pack's expectation counts its guaranteed Epic or better, as the draw itself does" do
    pool = Game::DrawPool::Snapshot.new(key: nil, season_id: nil, tiers: (1..5).to_h { [ it, [ it ] ] }, tier_by_id: (1..5).to_h { [ it, it ] })
    random = Random.new(261)
    scores = Array.new(60_000) { Game::RewardDraw.cards(pool:, random:).sum { Game::LuckOdds.points(it) } }
    mean = scores.sum.fdiv(scores.size)
    variance = scores.sum { (it - mean)**2 }.fdiv(scores.size)
    reward = Game::LuckOdds.of(:reward)

    assert_in_delta 30.296, reward.points, 0.001
    assert_in_delta 151.93, reward.variance, 0.01
    assert_in_delta reward.points, mean, 0.25
    assert_in_delta reward.variance, variance, 8
  end
end
