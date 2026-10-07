require "test_helper"
require_relative "../../support/game_packs"

# The weekly goal's reward (CAP-12, AD-7, AD-9; story 6.5): a reached goal
# rewards each contributor of its week with one reward pack (five cards, an
# Épique or better among them), once, outside the cap of ten; the job that
# serves them, its trigger from the periodic sum, and the reward pack opening
# like any pack.
class Game::GoalRewardTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks

  MONDAY = Time.utc(2026, 10, 5)
  WEEK = MONDAY.to_date

  setup do
    Game::DrawPool.reset!
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def contribute(player, week: WEEK, openings: 1)
    Game::WeeklyContribution.create!(player_id: player.id, week_start: week, openings:)
  end

  def goal(week: WEEK, total: 200, target: 200)
    Game::WeeklyGoal.create!(week_start: week, total:, target:)
  end

  def grant(player = @player, week: WEEK) = Game::GrantGoalReward.new.call(player:, week_start: week)
  def rewards(player = @player) = Game::GoalReward.where(player_id: player.id)
  def reward_packs(player = @player) = Game::Pack.where(player_id: player.id).reward

  def tier(id) = Game::DrawPool.current.tier_of(id)

  test "a contributor of a reached week gets one reward pack of five, an Épique or better among them, and the event" do
    goal
    contribute(@player)

    travel_to(MONDAY + 7.days + 1.minute) do
      pack = grant.value!

      assert_predicate pack, :reward?
      assert_equal Time.current, pack.available_at
      assert_nil pack.opened_at
      assert_equal Game::Pack::SIZE, pack.card_season_ids.size
      assert pack.card_season_ids.any? { |id| tier(id) >= 4 }, "a reward pack holds an Épique or better"
      assert_equal [ [ WEEK, pack.id ] ], rewards.pluck(:week_start, :pack_id)
      event = game_events(@player, Game::GoalRewardGranted).sole
      assert_equal({ player_id: @player.id, pack_id: pack.id, week_start: "2026-10-05" }, event.data)
    end
  end

  test "the reward draw always holds an Épique or better" do
    pool = Game::DrawPool.current
    200.times do |seed|
      cards = Game::RewardDraw.cards(pool:, random: Random.new(seed))
      assert_equal Game::Pack::SIZE, cards.size
      assert cards.any? { |id| pool.tier_of(id) >= Game::RewardDraw::MIN_TIER }, "seed #{seed}"
    end
    assert_equal Game::DrawOdds::TOTAL, Game::DrawOdds::EPIC_OR_BETTER.values.sum
    assert_equal Game::DrawOdds::TOTAL, Game::DrawOdds::REWARD.values.sum
  end

  test "a reward is granted once: a second grant is refused and writes nothing" do
    goal
    contribute(@player)
    grant.value!

    assert_equal :already_granted, grant.failure
    assert_equal 1, rewards.count
    assert_equal 1, reward_packs.count
    assert_equal 1, game_events(@player, Game::GoalRewardGranted).size
  end

  test "a full reserve does not lose the reward: it is added above ten" do
    goal
    contribute(@player)
    Game::FillBank.new.call(player: @player).value!
    assert Game::Reserve.full?(Game::Reserve.count(@player.id))

    grant.value!

    assert_equal 11, Game::Reserve.count(@player.id)
    assert_equal 10, Game::Pack.bank(@player.id).count
  end

  test "nothing is granted for a goal not reached, to a non-contributor, to a banned player or without a season" do
    goal(total: 199)
    contribute(@player)
    assert_equal :goal_not_reached, grant.failure

    Game::WeeklyGoal.where(week_start: WEEK).update_all(total: 200)
    assert_equal :not_contributor, grant(@other).failure

    banned = accounts_players(:banned)
    contribute(banned)
    assert_equal :player_required, grant(banned).failure

    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    assert_equal :no_season, grant.failure

    assert_equal 0, Game::GoalReward.count
    assert_equal 0, Game::Pack.reward.count
  end

  test "the reward pack opens like any pack: its five cards credited, no bank top-up" do
    goal
    contribute(@player)
    pack = grant.value!

    opened = Game::OpenPack.new.call(player: @player).value!

    assert_equal pack.id, opened.id
    assert_predicate opened.reload, :opened?
    assert_equal pack.card_season_ids.size, Game::Holding.where(player_id: @player.id).sum(:quantity)
    assert_equal 0, Game::Pack.bank(@player.id).count
  end

  test "the job rewards every contributor of a reached week once, skipping the banned, and a rerun grants nothing more" do
    goal
    banned = accounts_players(:banned)
    [ @player, @other, banned ].each { |player| contribute(player) }

    2.times { Game::GrantGoalRewardsJob.perform_now(week_start: WEEK) }

    assert_equal [ @other.id, @player.id ].sort, Game::GoalReward.where(week_start: WEEK).pluck(:player_id).sort
    assert_equal 2, Game::Pack.reward.count
  end

  test "the job grants nothing for a week not reached" do
    goal(total: 10)
    contribute(@player)

    Game::GrantGoalRewardsJob.perform_now(week_start: WEEK)

    assert_equal 0, Game::GoalReward.count
  end

  test "the sum enqueues the grant when a reached goal's total moves, and a late contributor is rewarded too" do
    contribute(@player, openings: 150)
    contribute(@other, openings: 49)
    now = MONDAY + 1.day

    assert_no_enqueued_jobs(only: Game::GrantGoalRewardsJob) { Game::SumWeeklyGoalJob.new.perform(now:) }
    assert_equal [ 199, 200 ], Game::WeeklyGoal.where(week_start: WEEK).pick(:total, :target)

    Game::WeeklyContribution.where(player_id: @other.id).update_all(openings: 50)
    assert_enqueued_with(job: Game::GrantGoalRewardsJob, args: [ { week_start: WEEK } ]) { Game::SumWeeklyGoalJob.new.perform(now:) }
    perform_enqueued_jobs(only: Game::GrantGoalRewardsJob)
    assert_equal 2, Game::GoalReward.count

    # An unchanged total enqueues nothing.
    assert_no_enqueued_jobs(only: Game::GrantGoalRewardsJob) { Game::SumWeeklyGoalJob.new.perform(now:) }

    late = Accounts::Player.create!(steam_id: "76561198000000999")
    contribute(late)
    perform_enqueued_jobs(only: Game::GrantGoalRewardsJob) { Game::SumWeeklyGoalJob.new.perform(now:) }
    assert_equal [ @player.id, @other.id, late.id ].sort, Game::GoalReward.pluck(:player_id).sort
    assert_equal 3, Game::Pack.reward.count
  end

  test "the hub's reward toast reads the newest reward whose pack is unopened" do
    goal
    contribute(@player)
    assert_nil Game::WaitingGoalReward.call(@player)

    grant.value!
    assert_equal WEEK, Game::WaitingGoalReward.call(@player)
    assert_nil Game::WaitingGoalReward.call(@other)

    Game::OpenPack.new.call(player: @player).value!
    assert_nil Game::WaitingGoalReward.call(@player)
  end
end
