require "test_helper"
require_relative "../../support/game_packs"

# The weekly goal (CAP-12, AD-9, AD-10, AD-12; story 6.3): a contribution row
# per player and week from each opening, the periodic sum and the target.
class Game::WeeklyGoalTest < ActiveSupport::TestCase
  include GamePacks

  MONDAY = Time.utc(2026, 10, 5)

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def contributions(player) = Game::WeeklyContribution.where(player_id: player.id).order(:week_start).pluck(:week_start, :openings)

  def open_for(player, at:)
    create_pack(player, available_at: at - 1.minute)
    travel_to(at) { Game::OpenPack.new.call(player:).value! }
  end

  def goal(week) = Game::WeeklyGoal.find_by!(week_start: week)

  test "the week starts on Monday 00:00 UTC" do
    assert_equal MONDAY.to_date, Game::WeeklyGoal.week_start(Time.utc(2026, 10, 11, 23, 59, 59))
    assert_equal MONDAY.to_date + 7, Game::WeeklyGoal.week_start(Time.utc(2026, 10, 12))
  end

  test "openings count on the opener's own row, one per player and week" do
    2.times { open_for(@player, at: MONDAY + 1.hour) }
    open_for(@other, at: MONDAY + 2.hours)
    open_for(@player, at: MONDAY + 7.days)

    assert_equal [ [ MONDAY.to_date, 2 ], [ MONDAY.to_date + 7, 1 ] ], contributions(@player)
    assert_equal [ [ MONDAY.to_date, 1 ] ], contributions(@other)
  end

  test "a replayed opening counts nothing" do
    key = SecureRandom.uuid
    create_pack(@player, available_at: MONDAY - 1.minute)
    travel_to(MONDAY) do
      2.times { Game::OpenPack.new.call(player: @player, idempotency_key: key).value! }
    end

    assert_equal [ [ MONDAY.to_date, 1 ] ], contributions(@player)
  end

  test "the job sums the contributions and fixes the target at the floor without a previous week" do
    open_for(@player, at: MONDAY + 1.hour)
    2.times { open_for(@other, at: MONDAY + 2.hours) }

    Game::SumWeeklyGoalJob.new.perform(now: MONDAY + 1.day)
    assert_equal [ 3, 200 ], [ goal(MONDAY.to_date).total, goal(MONDAY.to_date).target ]

    open_for(@player, at: MONDAY + 2.days)
    Game::SumWeeklyGoalJob.new.perform(now: MONDAY + 2.days)
    assert_equal 4, goal(MONDAY.to_date).total
  end

  test "the target is the previous week's active players times fifty, never under 200" do
    next_week = MONDAY.to_date + 7
    assert_equal 200, Game::WeeklyGoal.target_for(next_week)

    Game::WeeklyContribution.create!(player_id: @player.id, week_start: MONDAY.to_date, openings: 1)
    assert_equal 200, Game::WeeklyGoal.target_for(next_week)

    players = Array.new(9) { |index| Accounts::Player.create!(steam_id: "7656119800000010#{index}") }
    players.each { |player| Game::WeeklyContribution.create!(player_id: player.id, week_start: MONDAY.to_date, openings: 3) }
    # Ten active players, plus a player of another week who does not count.
    Game::WeeklyContribution.create!(player_id: @other.id, week_start: MONDAY.to_date - 7, openings: 5)
    assert_equal 500, Game::WeeklyGoal.target_for(next_week)
  end

  test "the sum is idempotent and a week ending is summed one last time" do
    open_for(@player, at: MONDAY + 6.days + 23.hours)
    Game::SumWeeklyGoalJob.new.perform(now: MONDAY + 6.days + 23.hours)
    open_for(@player, at: MONDAY + 6.days + 23.hours + 59.minutes)
    2.times { Game::SumWeeklyGoalJob.new.perform(now: MONDAY + 7.days + 1.minute) }

    assert_equal 2, goal(MONDAY.to_date).total
    assert_equal [ 0, 200 ], [ goal(MONDAY.to_date + 7).total, goal(MONDAY.to_date + 7).target ]
  end

  test "the current goal reads the summed row, or zero and the computed target before the job" do
    now = MONDAY + 1.hour
    assert_equal({ total: 0, target: 200 }, Game::CurrentGoal.call(now:))
    open_for(@player, at: now)
    Game::SumWeeklyGoalJob.new.perform(now:)
    assert_equal({ total: 1, target: 200 }, Game::CurrentGoal.call(now:))
  end
end
