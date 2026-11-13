require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/game_trades"

# The weekly goal: a contribution row
# per player and week from each opening, the periodic sum and the target.
class Game::WeeklyGoalTest < ActiveSupport::TestCase
  include GamePacks
  include GameTrades

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
    assert_equal [ 3, 500 ], [ goal(MONDAY.to_date).total, goal(MONDAY.to_date).target ]

    open_for(@player, at: MONDAY + 2.days)
    Game::SumWeeklyGoalJob.new.perform(now: MONDAY + 2.days)
    assert_equal 4, goal(MONDAY.to_date).total
  end

  def previous_week(target:, done:)
    Game::WeeklyGoal.create!(week_start: MONDAY.to_date, target:, total: 0)
    Game::WeeklyContribution.create!(player_id: @player.id, week_start: MONDAY.to_date, openings: done - 1, trades: 0)
    Game::WeeklyContribution.create!(player_id: @other.id, week_start: MONDAY.to_date, openings: 0, trades: 1)
    Game::WeeklyGoal.target_for(MONDAY.to_date + 7)
  end

  test "without a previous week the target is the floor" do
    Game::WeeklyContribution.create!(player_id: @player.id, week_start: MONDAY.to_date, openings: 900)

    assert_equal 500, Game::WeeklyGoal.target_for(MONDAY.to_date + 7)
  end

  test "a reached week sets the next target five percent above what was done, rounded up to ten" do
    assert_equal 1370, previous_week(target: 1000, done: 1300)
  end

  test "a week reached exactly raises the target by five percent" do
    assert_equal 1050, previous_week(target: 1000, done: 1000)
  end

  test "a missed week lowers the target halfway toward what was done" do
    assert_equal 800, previous_week(target: 1000, done: 600)
  end

  test "a missed week never lowers the target under the floor" do
    assert_equal 500, previous_week(target: 600, done: 100)
  end

  test "the target reads only the previous week, never an older one" do
    Game::WeeklyContribution.create!(player_id: @other.id, week_start: MONDAY.to_date - 7, openings: 5_000)

    assert_equal 600, previous_week(target: 1000, done: 200)
  end

  test "the job fixes the new week's target from the week before, and the page reads the same figure before it runs" do
    Game::WeeklyGoal.create!(week_start: MONDAY.to_date, target: 1000, total: 0)
    Game::WeeklyContribution.create!(player_id: @player.id, week_start: MONDAY.to_date, openings: 1299, trades: 1)

    assert_equal 1370, Game::CurrentGoal.call(now: MONDAY + 7.days)[:target]
    Game::SumWeeklyGoalJob.new.perform(now: MONDAY + 7.days)
    assert_equal [ 0, 1370 ], [ goal(MONDAY.to_date + 7).total, goal(MONDAY.to_date + 7).target ]
  end

  test "the sum is idempotent and a week ending is summed one last time" do
    open_for(@player, at: MONDAY + 6.days + 23.hours)
    Game::SumWeeklyGoalJob.new.perform(now: MONDAY + 6.days + 23.hours)
    open_for(@player, at: MONDAY + 6.days + 23.hours + 59.minutes)
    2.times { Game::SumWeeklyGoalJob.new.perform(now: MONDAY + 7.days + 1.minute) }

    assert_equal 2, goal(MONDAY.to_date).total
    assert_equal [ 0, 500 ], [ goal(MONDAY.to_date + 7).total, goal(MONDAY.to_date + 7).target ]
  end

  test "the current goal reads the summed row, or zero and the computed target before the job" do
    now = MONDAY + 1.hour
    assert_equal({ total: 0, target: 500, reached: false, previous: nil }, Game::CurrentGoal.call(now:))
    open_for(@player, at: now)
    Game::SumWeeklyGoalJob.new.perform(now:)
    assert_equal({ total: 1, target: 500, reached: false, previous: nil }, Game::CurrentGoal.call(now:))
  end

  test "the current goal is reached at its target, and after the rollover shows the previous week's final count" do
    Game::WeeklyGoal.create!(week_start: MONDAY.to_date, total: 200, target: 200)
    assert_equal({ total: 200, target: 200, reached: true, previous: nil }, Game::CurrentGoal.call(now: MONDAY + 1.day))

    Game::WeeklyGoal.where(week_start: MONDAY.to_date).update_all(total: 180)
    # The new week before the job ran: an empty gauge, a new target, last week missed.
    assert_equal({ total: 0, target: 500, reached: false, previous: { total: 180, target: 200, reached: false } },
      Game::CurrentGoal.call(now: MONDAY + 7.days))

    Game::WeeklyGoal.create!(week_start: MONDAY.to_date + 7, total: 12, target: 250)
    assert_equal({ total: 12, target: 250, reached: false, previous: { total: 180, target: 200, reached: false } },
      Game::CurrentGoal.call(now: MONDAY + 7.days))
  end

  def trade_at(at, proposer: @player, recipient: @other)
    travel_to(at) { conclude_trade(proposer, recipient, offer: { fixture_tier_ids[3] => 1 }, request: { fixture_tier_ids[2] => 1 }) }
  end

  test "a trade counts once for the pair: credited to its recipient, both players with a row" do
    2.times { open_for(@player, at: MONDAY + 1.hour) }
    2.times { open_for(@other, at: MONDAY + 1.hour) }
    trade_at(MONDAY + 2.hours)

    Game::SumWeeklyGoalJob.new.perform(now: MONDAY + 1.day)

    assert_equal 5, goal(MONDAY.to_date).total
    rows = Game::WeeklyContribution.where(week_start: MONDAY.to_date)
    assert_equal({ @player.id => [ 2, 0 ], @other.id => [ 2, 1 ] }, rows.pluck(:player_id, :openings, :trades).to_h { |id, *counts| [ id, counts ] })
  end

  test "a player who only traded has a row" do
    trade_at(MONDAY + 1.hour)

    assert_equal [ [ 0, 0 ], [ 0, 1 ] ], [ @player, @other ].map { |player|
      Game::WeeklyContribution.find_by!(player_id: player.id, week_start: MONDAY.to_date).values_at(:openings, :trades)
    }
  end
end
