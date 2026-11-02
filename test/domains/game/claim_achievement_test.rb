require "test_helper"
require_relative "../../support/game_packs"

class Game::ClaimAchievementTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def unlock(key, player: @player, claimed: false)
    Game::AchievementUnlock.record(player.id, key, Time.current, claimed:)
  end

  def opened_packs(count, player: @player) = count.times { create_pack(player, opened_at: Time.current) }
  def claim(key, player: @player) = Game::ClaimAchievement.new.call(player:, achievement: key)
  def claimed_at(key, player: @player) = Game::AchievementUnlock.find_by!(player_id: player.id, achievement: key).claimed_at
  def backs(player = @player) = Game::CardBackUnlock.where(player_id: player.id).pluck(:back)
  def claim_events(player = @player) = game_events(player, Game::AchievementClaimed)

  test "claiming an earned achievement marks it claimed, publishes one event and grants its back" do
    unlock("boosters_100")

    perform_enqueued_jobs { assert claim("boosters_100").success? }

    assert claimed_at("boosters_100")
    assert_equal [ "boosters_100" ], claim_events.map { it.data[:achievement] }
    assert_equal [ "centurion" ], backs
  end

  test "an achievement earned and not claimed gives no back" do
    unlock("boosters_100")

    perform_enqueued_jobs { Game::GrantCardBacksJob.perform_now(@player.id) }

    assert_empty backs
  end

  test "an achievement not earned is refused" do
    assert_equal :achievement_not_earned, claim("boosters_100").failure
    assert_empty claim_events
  end

  test "another player's achievement is refused" do
    unlock("boosters_100", player: @other)

    assert_equal :achievement_not_earned, claim("boosters_100").failure
    assert_nil claimed_at("boosters_100", player: @other)
  end

  test "a claimed achievement is refused a second time" do
    unlock("boosters_100", claimed: true)

    assert_equal :achievement_already_claimed, claim("boosters_100").failure
    assert_empty claim_events
  end

  test "an unknown achievement is refused" do
    assert_equal :unknown_achievement, claim("nope").failure
  end

  test "an achievement without a reward is born claimed" do
    assert_nil Game::CardBacks.for_achievement(:first_booster)

    opened_packs(1)
    perform_enqueued_jobs { Game::GrantAchievement.new.call(player: @player, achievement: :first_booster).value! }

    assert claimed_at("first_booster")
    assert_equal 0, Game::UnclaimedAchievements.count(@player)
  end

  test "an achievement with a reward waits for its claim unless granted retroactively" do
    opened_packs(100)
    opened_packs(100, player: @other)
    Game::GrantAchievement.new.call(player: @player, achievement: :boosters_100).value!
    Game::GrantAchievement.new.call(player: @other, achievement: :boosters_100, retroactive: true).value!

    assert_nil claimed_at("boosters_100")
    assert claimed_at("boosters_100", player: @other)
  end

  test "the unclaimed count holds the earned achievements waiting for a claim" do
    unlock("boosters_100")
    unlock("first_legendary")
    unlock("first_booster", claimed: true)

    assert_equal 2, Game::UnclaimedAchievements.count(@player)
    assert_equal 0, Game::UnclaimedAchievements.count(@other)
    assert_equal 0, Game::UnclaimedAchievements.count(nil)
  end
end
