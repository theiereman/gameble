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
    Game::AchievementUnlock.create!(player_id: player.id, achievement: key, unlocked_at: Time.current)
  end

  def achievement_event(key, retroactive: false)
    data = { player_id: @player.id, achievement: key }
    Game::AchievementUnlocked.new(data: retroactive ? data.merge(retroactive: true) : data)
  end

  test "the catalogue names the goal, achievement and event backs with their rules" do
    assert_equal :goal, Game::CardBacks.find("confrere").unlock.kind
    assert_equal [ :achievement, "boosters_100" ], Game::CardBacks.find("centurion").unlock.to_h.values_at(:kind, :target)
    assert_equal [ :achievement, "first_legendary" ], Game::CardBacks.find("etoile-dor").unlock.to_h.values_at(:kind, :target)
    assert_equal [ :achievement, "three_complete_sets" ], Game::CardBacks.find("aurore").unlock.to_h.values_at(:kind, :target)
    assert_equal %w[saison-1 millesime-2017 soldes-hiver], Game::CardBacks::EVENT_BACK_KEYS
    assert(Game::CardBacks::EVENT_BACK_KEYS.all? { Game::CardBacks.event?(it) })
    assert_not Game::CardBacks.event?("aurore")
  end

  test "the first goal reward grants Confrère once, the second adds nothing" do
    perform_enqueued_jobs { earn_goal_reward }
    assert_equal [ "confrere" ], unlocked

    perform_enqueued_jobs { earn_goal_reward(week: WEEK + 7) }
    assert_equal [ "confrere" ], unlocked
    assert_equal 1, unlock_events.size
    assert_not unlock_events.sole.data[:retroactive]
  end

  test "the back comes with the reward, not with its claim" do
    perform_enqueued_jobs { earn_goal_reward }
    assert_equal [ "confrere" ], unlocked

    perform_enqueued_jobs { Game::ClaimGoalReward.new.call(player: @player, week_start: WEEK) }
    assert_equal [ "confrere" ], unlocked
    assert_equal 1, unlock_events.size
  end

  { "boosters_100" => "centurion", "first_legendary" => "etoile-dor", "three_complete_sets" => "aurore" }.each do |achievement, back|
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

  test "granting the achievement itself grants its back through the subscribed handler" do
    progress = Hash.new(0).merge(legendaries_obtained: 1)
    original = Game::AchievementProgress.method(:call)
    Game::AchievementProgress.define_singleton_method(:call) { |_player| progress }

    perform_enqueued_jobs { Game::GrantAchievement.new.call(player: @player, achievement: "first_legendary").value! }

    assert_equal [ "etoile-dor" ], unlocked
  ensure
    Game::AchievementProgress.define_singleton_method(:call, original)
  end

  test "another player's reward grants nothing to this player" do
    perform_enqueued_jobs { earn_goal_reward(@other) }

    assert_empty unlocked
    assert_equal [ "confrere" ], unlocked(@other)
  end

  test "a banned player is granted nothing" do
    earn_goal_reward
    @player.update!(banned_at: Time.current)
    perform_enqueued_jobs

    assert_empty unlocked
  end

  test "the backfill grants the goal and achievement backs earned before, silently, and run twice writes once" do
    earn_goal_reward
    record_achievement("boosters_100")
    record_achievement("first_booster")

    capture_io { 2.times { rake_task("game:backfill_card_backs").execute } }

    assert_equal %w[centurion confrere], unlocked.sort
    assert_equal 2, unlock_events.size
    assert(unlock_events.all? { it.data[:retroactive] })
  end
end
