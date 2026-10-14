require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/game_trades"

# The weekly goal's reward: a reached goal earns each contributor of its week
# one reward, once, which waits until the player claims it; the claim draws
# the reward pack (five cards, an Épique or better among them) while the
# reserve has room. Also the job that grants them, its trigger from the
# periodic sum, the hub's claim slot state, and the reward pack opening like
# any pack.
class Game::GoalRewardTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks
  include GameTrades

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
  def claim(player = @player, week: WEEK) = Game::ClaimGoalReward.new.call(player:, week_start: week)
  def rewards(player = @player) = Game::GoalReward.where(player_id: player.id)
  def reward_packs(player = @player) = Game::Pack.where(player_id: player.id).reward

  def earned(player = @player, week: WEEK)
    goal(week:) unless Game::WeeklyGoal.exists?(week_start: week)
    contribute(player, week:)
    grant(player, week:).value!
  end

  def tier(id) = Game::DrawPool.current.tier_of(id)

  test "a contributor of a reached week earns one waiting reward without a pack, and the event" do
    goal
    contribute(@player)

    reward = grant.value!

    assert_equal [ [ WEEK, nil ] ], rewards.pluck(:week_start, :pack_id)
    assert_not_predicate reward, :claimed?
    assert_equal 0, reward_packs.count
    assert_equal 0, Game::Reserve.count(@player.id)
    event = game_events(@player, Game::GoalRewardGranted).sole
    assert_equal({ player_id: @player.id, week_start: "2026-10-05" }, event.data)
  end

  test "a reward is earned once: a second grant is refused and writes nothing" do
    earned

    assert_equal :already_granted, grant.failure
    assert_equal 1, rewards.count
    assert_equal 1, game_events(@player, Game::GoalRewardGranted).size
  end

  test "nothing is earned for a goal not reached, by a non-contributor or by a banned player" do
    goal(total: 199)
    contribute(@player)
    assert_equal :goal_not_reached, grant.failure

    Game::WeeklyGoal.where(week_start: WEEK).update_all(total: 200)
    assert_equal :not_contributor, grant(@other).failure

    banned = accounts_players(:banned)
    contribute(banned)
    assert_equal :player_required, grant(banned).failure

    assert_equal 0, Game::GoalReward.count
  end

  test "a claim adds one reward pack of five, an Épique or better among them, available now, linked to the reward" do
    earned

    travel_to(MONDAY + 7.days + 1.minute) do
      pack = claim.value!

      assert_predicate pack, :reward?
      assert_equal Time.current, pack.available_at
      assert_nil pack.opened_at
      assert_equal Game::DrawPool.current.season_id, pack.season_id
      assert_equal Game::Pack::SIZE, pack.card_season_ids.size
      assert pack.card_season_ids.any? { |id| tier(id) >= 4 }, "a reward pack holds an Épique or better"
      assert_equal [ [ WEEK, pack.id ] ], rewards.pluck(:week_start, :pack_id)
      assert_equal 1, Game::Reserve.count(@player.id)
      event = game_events(@player, Game::GoalRewardClaimed).sole
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

  test "a second claim of the same reward is refused and adds nothing" do
    earned
    pack = claim.value!

    assert_equal :reward_already_claimed, claim.failure
    assert_equal [ pack.id ], reward_packs.ids
    assert_equal 1, game_events(@player, Game::GoalRewardClaimed).size
  end

  test "a full reserve refuses the claim and the reward waits; after an opening the claim succeeds" do
    earned
    Game::FillBank.new.call(player: @player).value!
    assert Game::Reserve.full?(Game::Reserve.count(@player.id))

    assert_equal :reward_reserve_full, claim.failure
    assert_equal 0, reward_packs.count
    assert_equal [ nil ], rewards.pluck(:pack_id)
    assert_empty game_events(@player, Game::GoalRewardClaimed)

    Game::OpenPack.new.call(player: @player).value!
    claim.value!

    assert_equal 1, reward_packs.count
    assert_equal Game::Reserve::FULL, Game::Reserve.count(@player.id)
  end

  test "a claim is refused for a week not earned, by another player, by a banned player and without a season" do
    earned

    assert_equal :reward_not_earned, claim(week: WEEK - 7).failure
    assert_equal :reward_not_earned, claim(week: nil).failure
    assert_equal :reward_not_earned, claim(@other).failure

    banned = accounts_players(:banned)
    assert_equal :player_required, claim(banned).failure

    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    Game::DrawPool.reset!
    assert_equal :reward_no_season, claim.failure

    assert_equal [ nil ], rewards.pluck(:pack_id)
    assert_equal 0, Game::Pack.reward.count
  end

  test "the claimed reward pack opens like any pack: its five cards credited, no bank top-up" do
    earned
    pack = claim.value!

    opened = Game::OpenPack.new.call(player: @player).value!

    assert_equal pack.id, opened.id
    assert_predicate opened.reload, :opened?
    assert_equal pack.card_season_ids.size, Game::Holding.where(player_id: @player.id).sum(:quantity)
    assert_equal 0, Game::Pack.bank(@player.id).count
  end

  test "the claim slot offers the oldest waiting reward, else the reward claimed last while its claim is of the current or previous week" do
    now = MONDAY + 7.days + 1.hour
    status = -> { Game::GoalRewardStatus.call(@player, now: Time.current) }

    travel_to(now) do
      assert_nil status.call

      earned(week: WEEK - 14)
      earned(week: WEEK)
      assert_equal({ week_start: WEEK - 14, claimed: false }, status.call)
      assert_nil Game::GoalRewardStatus.call(@other)

      claim(week: WEEK - 14).value!
      assert_equal({ week_start: WEEK, claimed: false }, status.call)
    end

    travel_to(now + 1.hour) do
      claim.value!
      assert_equal({ week_start: WEEK, claimed: true }, status.call)
    end

    travel_to(now + 7.days) { assert_equal({ week_start: WEEK, claimed: true }, status.call) }
    travel_to(now + 14.days) { assert_nil status.call }
  end

  test "a reward three weeks old, once claimed, reads as collected" do
    old_week = WEEK - 21
    earned(week: old_week)

    travel_to(MONDAY + 2.days) do
      claim(week: old_week).value!

      assert_equal({ week_start: old_week, claimed: true }, Game::GoalRewardStatus.call(@player))
    end
  end

  test "a reward granted with its pack before claims existed reads as collected" do
    goal
    pack = create_pack(@player, kind: :reward)
    Game::GoalReward.create!(player_id: @player.id, week_start: WEEK, pack_id: pack.id)

    assert_equal({ week_start: WEEK, claimed: true }, Game::GoalRewardStatus.call(@player, now: MONDAY + 1.day))
    assert_equal :reward_already_claimed, claim.failure
  end

  test "the job rewards every contributor of a reached week once, skipping the banned, and a rerun grants nothing more" do
    goal
    banned = accounts_players(:banned)
    [ @player, @other, banned ].each { |player| contribute(player) }

    2.times { Game::GrantGoalRewardsJob.perform_now(week_start: WEEK) }

    assert_equal [ @other.id, @player.id ].sort, Game::GoalReward.where(week_start: WEEK).pluck(:player_id).sort
    assert_equal 0, Game::Pack.reward.count
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
  end

  test "a player whose only contribution of a reached week is a trade gets the reward, as does the other trader" do
    travel_to(MONDAY + 1.hour) do
      conclude_trade(@player, @other, offer: { fixture_tier_ids[3] => 1 }, request: { fixture_tier_ids[2] => 1 })
    end
    goal

    Game::GrantGoalRewardsJob.perform_now(week_start: WEEK)

    assert_equal [ @other.id, @player.id ].sort, Game::GoalReward.where(week_start: WEEK).pluck(:player_id).sort
  end
end
