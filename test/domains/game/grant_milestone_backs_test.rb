require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/rake_tasks"

class Game::GrantMilestoneBacksTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks
  include RakeTasks

  MONDAY = Time.utc(2026, 10, 5)
  WEEK = MONDAY.to_date

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def unlocked(player = @player) = Game::CardBackUnlock.where(player_id: player.id).order(:id).pluck(:back)
  def unlock_events(player = @player) = game_events(player, Game::CardBackUnlocked)

  def earn_goal_reward(player = @player, week: WEEK)
    Game::WeeklyGoal.find_or_create_by!(week_start: week) { it.total = 200; it.target = 200 }
    Game::WeeklyContribution.create!(player_id: player.id, week_start: week, openings: 1)
    Game::GrantGoalReward.new.call(player:, week_start: week).value!
  end

  def record_achievement(key, player: @player)
    Game::AchievementUnlock.create!(player_id: player.id, achievement: key, unlocked_at: Time.current, claimed_at: Time.current)
  end

  def achievement_event(key, retroactive: false)
    data = { player_id: @player.id, achievement: key }
    Game::AchievementUnlocked.new(data: retroactive ? data.merge(retroactive: true) : data)
  end

  test "a goal reward grants no card back" do
    perform_enqueued_jobs { earn_goal_reward }

    assert_empty unlocked
  end

  {
    "boosters_100" => "centurion", "first_legendary" => "etoile-dor", "three_complete_sets" => "aurore",
    "luck_is_a_marketing_concept" => "trefle-fane", "leave_request_denied" => "assidu",
    "market_concentration" => "siege-social", "a_strictly_professional_relationship" => "contrat"
  }.each do |achievement, back|
    test "the achievement #{achievement} grants #{back} once" do
      record_achievement(achievement)
      event = achievement_event(achievement)
      perform_enqueued_jobs { Game::Handlers::CardBacks.call(event) }
      perform_enqueued_jobs { Game::Handlers::CardBacks.call(event) }

      assert_equal [ back ], unlocked
      assert_equal 1, unlock_events.size
      assert_not unlock_events.sole.data[:retroactive]
    end
  end

  {
    "luck_is_a_marketing_concept" => "trefle-fane", "leave_request_denied" => "assidu",
    "market_concentration" => "siege-social", "a_strictly_professional_relationship" => "contrat"
  }.each do |achievement, back|
    test "the achievement #{achievement} names #{back} in the catalogue and tells its player in play, not from the backfill" do
      assert_equal [ :achievement, achievement ], Game::CardBacks.find(back).unlock.to_h.values_at(:kind, :target)
      assert_equal back, Game::CardBacks.for_achievement(achievement).key

      assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @player.id, card_back: back } ] ]) do
        Game::UnlockCardBack.new.call(player: @player, back:).value!
      end
      assert_no_enqueued_jobs(only: PlayerStreamJob) do
        Game::UnlockCardBack.new.call(player: @other, back:, retroactive: true).value!
      end
    end
  end

  test "an achievement without a back grants nothing" do
    record_achievement("first_booster")
    perform_enqueued_jobs { Game::Handlers::CardBacks.call(achievement_event("first_booster")) }

    assert_empty unlocked
  end

  test "a retroactive achievement unlock grants its back silently" do
    record_achievement("boosters_100")
    perform_enqueued_jobs { Game::Handlers::CardBacks.call(achievement_event("boosters_100", retroactive: true)) }

    assert_equal [ "centurion" ], unlocked
    assert unlock_events.sole.data[:retroactive]
  end

  test "granting the achievement leaves its back to the claim, which grants it through the subscribed handler" do
    progress = Hash.new(0).merge(legendaries_obtained: 1)
    original = Game::AchievementProgress.method(:call)
    Game::AchievementProgress.define_singleton_method(:call) { |_player, _metrics| progress }

    perform_enqueued_jobs { Game::GrantAchievement.new.call(player: @player, achievement: "first_legendary").value! }

    assert_empty unlocked

    perform_enqueued_jobs { Game::ClaimAchievement.new.call(player: @player, achievement: "first_legendary").value! }

    assert_equal [ "etoile-dor" ], unlocked
  ensure
    Game::AchievementProgress.define_singleton_method(:call, original)
  end

  test "another player's achievement grants nothing to this player" do
    record_achievement("boosters_100", player: @other)
    perform_enqueued_jobs { Game::GrantCardBacksJob.perform_now(@other.id) }

    assert_empty unlocked
    assert_equal [ "centurion" ], unlocked(@other)
  end

  test "a banned player is granted nothing" do
    record_achievement("boosters_100")
    @player.update!(banned_at: Time.current)
    perform_enqueued_jobs { Game::GrantCardBacksJob.perform_now(@player.id) }

    assert_empty unlocked
  end

  test "the backfill grants the achievement backs earned before, silently, and run twice writes once" do
    record_achievement("boosters_100")
    record_achievement("three_complete_sets")
    record_achievement("first_booster")

    capture_io { 2.times { rake_task("game:backfill_card_backs").execute } }

    assert_equal %w[aurore centurion], unlocked.sort
    assert_equal 2, unlock_events.size
    assert(unlock_events.all? { it.data[:retroactive] })
  end
end
