require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/game_trades"

# The weekly goal (CAP-12, AD-9, AD-10, AD-12; story 6.3): a contribution row
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
    assert_equal({ total: 0, target: 200, reached: false, previous: nil }, Game::CurrentGoal.call(now:))
    open_for(@player, at: now)
    Game::SumWeeklyGoalJob.new.perform(now:)
    assert_equal({ total: 1, target: 200, reached: false, previous: nil }, Game::CurrentGoal.call(now:))
  end

  test "the current goal is reached at its target, and after the rollover shows the previous week's final count" do
    Game::WeeklyGoal.create!(week_start: MONDAY.to_date, total: 200, target: 200)
    assert_equal({ total: 200, target: 200, reached: true, previous: nil }, Game::CurrentGoal.call(now: MONDAY + 1.day))

    Game::WeeklyGoal.where(week_start: MONDAY.to_date).update_all(total: 180)
    # The new week before the job ran: an empty gauge, a new target, last week missed.
    assert_equal({ total: 0, target: 200, reached: false, previous: { total: 180, target: 200, reached: false } },
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

  test "a player who only traded has a row, but is not active for the next week's target" do
    trade_at(MONDAY + 1.hour)
    active = Array.new(4) { |index| Accounts::Player.create!(steam_id: "7656119800000020#{index}") }
    active.each { |player| Game::WeeklyContribution.create!(player_id: player.id, week_start: MONDAY.to_date, openings: 1) }

    assert_equal [ [ 0, 0 ], [ 0, 1 ] ], [ @player, @other ].map { |player|
      Game::WeeklyContribution.find_by!(player_id: player.id, week_start: MONDAY.to_date).values_at(:openings, :trades)
    }
    assert_equal 200, Game::WeeklyGoal.target_for(MONDAY.to_date + 7)
  end
end
