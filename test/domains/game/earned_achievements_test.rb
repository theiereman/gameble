require "test_helper"

class Game::EarnedAchievementsTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @now = Time.utc(2026, 10, 19, 12, 0)
  end

  def unlock(key, at, player: @player)
    Game::AchievementUnlock.create!(player_id: player.id, achievement: key, unlocked_at: at, collected_at: at)
  end

  test "the count over the catalogue and the four latest earned, newest first, a tie by key, in one query" do
    unlock("first_booster", @now - 5.days)
    unlock("first_epic", @now - 4.days)
    unlock("first_trade", @now - 1.day)
    unlock("boosters_10", @now - 2.days)
    unlock("first_legendary", @now - 2.days)
    unlock("first_repost", @now - 3.days)
    unlock("three_complete_sets", @now, player: accounts_players(:moderator))

    earned = nil
    assert_queries_count(1) { earned = Game::EarnedAchievements.call(@player) }

    assert_equal [ 6, 10 ], [ earned.count, earned.total ]
    assert_equal %i[first_trade boosters_10 first_legendary first_repost], earned.latest.map(&:key)
    assert earned.latest.all?(&:earned)
    assert_equal [ 1, 10, 1, 1 ], earned.latest.map(&:threshold)
  end

  test "fewer than four earned: as many tiles" do
    unlock("first_booster", @now - 1.day)
    unlock("first_epic", @now)

    assert_equal %i[first_epic first_booster], Game::EarnedAchievements.call(@player).latest.map(&:key)
  end

  test "an unlock whose key the catalogue no longer holds is neither counted nor shown" do
    unlock("retired_achievement", @now)
    unlock("first_booster", @now - 1.day)

    earned = Game::EarnedAchievements.call(@player)

    assert_equal 1, earned.count
    assert_equal %i[first_booster], earned.latest.map(&:key)
  end

  test "a reached achievement not yet collected is counted as ready, never as earned" do
    unlock("first_booster", @now - 1.day)
    Game::AchievementUnlock.create!(player_id: @player.id, achievement: "first_epic", unlocked_at: @now)

    earned = nil
    assert_queries_count(1) { earned = Game::EarnedAchievements.call(@player) }

    assert_equal [ 1, 1 ], [ earned.count, earned.ready ]
    assert_equal %i[first_booster], earned.latest.map(&:key)
  end

  test "nothing earned, without a query, for nil" do
    assert_queries_count(0) do
      assert_equal Game::EarnedAchievements::Earned.new(count: 0, total: 10, latest: [], ready: 0), Game::EarnedAchievements.call(nil)
    end
  end
end
