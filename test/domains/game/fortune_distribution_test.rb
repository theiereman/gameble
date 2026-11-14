require "test_helper"

class Game::FortuneDistributionTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 11, 4, 12)

  def player(number, **attributes) = Accounts::Player.create!(steam_id: (76561197960500000 + number).to_s, **attributes)

  def luck(player, z_score, week_start: Game::WeeklyGoal.week_start(NOW))
    Game::Fortune.insert_all!([ { player_id: player.id, week_start:, regular_packs: 1, actual_points: (z_score * 100).round,
      expected_points: 0, variance: 10_000, created_at: NOW, updated_at: NOW } ])
  end

  test "players fall in the band of their index, private players aside, and a crowded band is hot" do
    2.times { |number| luck(player(number), 0.0) }
    luck(player(2), 40.0)
    luck(player(3, visibility: :private), -40.0)

    result = Game::FortuneDistribution.call(now: NOW)

    assert_equal 49, result.counts.size
    assert_equal 3, result.total
    assert_equal [ 2, 1, 0 ], result.counts.values_at(24, 48, 0)
    assert_equal 0, result.crowded_index
    assert_equal [ 18, :hot ], result.columns[24].deconstruct
    assert_equal [ 9, :warm ], result.columns[48].deconstruct
    assert_equal [ 0, :cold ], result.columns[0].deconstruct
  end

  test "only this week counts, and an empty week has no heat" do
    luck(player(1), 0.0, week_start: Game::WeeklyGoal.week_start(NOW) - 7)
    luck(player(2), 0.0, week_start: nil)

    result = Game::FortuneDistribution.call(now: NOW)

    assert_equal 0, result.total
    assert_equal [ 0, :cold ], result.columns.first.deconstruct
    assert_equal 1, Game::FortuneDistribution.call(:all_time, now: NOW).total
  end

  test "an index and its band convert both ways" do
    assert_equal 0, Game::FortuneDistribution.band_of(-500)
    assert_equal 24, Game::FortuneDistribution.band_of(0)
    assert_equal 48, Game::FortuneDistribution.band_of(500)
    assert_equal 0, Game::FortuneDistribution.index_of(24)
  end
end
