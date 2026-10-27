require "test_helper"

class Game::WeeklyGoalOperationsTest < ActiveSupport::TestCase
  WEEK = Date.new(2026, 10, 5)

  test "creating a weekly goal twice leaves the one row" do
    2.times { Game::CreateWeeklyGoal.new.call(week_start: WEEK).value! }

    assert_equal [ [ 0, 200 ] ], Game::WeeklyGoal.where(week_start: WEEK).pluck(:total, :target)
  end

  test "summing reports whether the total moved" do
    Game::CreateWeeklyGoal.new.call(week_start: WEEK).value!
    Game::WeeklyContribution.create!(player_id: accounts_players(:player).id, week_start: WEEK, openings: 3, trades: 2)

    assert_equal true, Game::SumWeeklyGoal.new.call(week_start: WEEK, now: Time.current).value!
    assert_equal false, Game::SumWeeklyGoal.new.call(week_start: WEEK, now: Time.current).value!
    assert_equal 5, Game::WeeklyGoal.find_by!(week_start: WEEK).total
  end

  test "summing a week without a goal moves nothing" do
    assert_equal false, Game::SumWeeklyGoal.new.call(week_start: WEEK, now: Time.current).value!
  end

  test "recording a player's activity replaces the previous one" do
    player_id = accounts_players(:player).id
    earlier = Time.utc(2026, 10, 7, 9)
    later = earlier + 1.hour
    Game::RecordPlayerActivity.new.call(player_id:, activity: :trading, at: earlier).value!
    Game::RecordPlayerActivity.new.call(player_id:, activity: :opening_pack, at: later).value!

    assert_equal [ "opening_pack", later ], Game::PlayerState.find_by!(player_id:).slice(:last_activity, :last_activity_at).values
  end
end
