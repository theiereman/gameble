require "test_helper"
require_relative "../../support/game_packs"

class Game::CollectAchievementTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def reach(key, player: @player) = Game::AchievementUnlock.record(player.id, key, 1.hour.ago)
  def collect(key, player: @player) = Game::CollectAchievement.new.call(player:, achievement: key)
  def collected_at(key, player: @player) = Game::AchievementUnlock.where(player_id: player.id, achievement: key).pick(:collected_at)

  test "collecting a reached achievement stamps it and publishes one event on the player's stream" do
    reach(:first_booster)

    result = collect("first_booster")

    assert_equal :first_booster, result.value!.key
    assert_not_nil collected_at("first_booster")
    event = game_events(@player, Game::AchievementCollected).sole
    assert_equal({ player_id: @player.id, achievement: "first_booster" }, event.data.slice(:player_id, :achievement))
  end

  test "an achievement is collected once" do
    reach(:first_booster)
    collect("first_booster").value!
    stamped = collected_at("first_booster")

    assert_equal :not_ready, collect("first_booster").failure
    assert_equal stamped, collected_at("first_booster")
    assert_equal 1, game_events(@player, Game::AchievementCollected).size
  end

  test "an achievement not reached, or reached by another player, cannot be collected" do
    reach(:first_epic, player: @other)

    assert_equal :not_ready, collect("first_epic").failure
    assert_equal :not_ready, collect("first_trade").failure
    assert_nil collected_at("first_epic", player: @other)
    assert_empty game_events(@player, Game::AchievementCollected)
  end

  test "an unknown key or a banned player is refused" do
    reach(:first_booster)

    assert_equal :unknown_achievement, collect("no_such_achievement").failure
    @player.update!(banned_at: Time.current)
    assert_equal :player_required, collect("first_booster").failure
    assert_nil collected_at("first_booster")
  end

  test "both refusals read in English and in French" do
    %i[not_ready unknown_achievement].each do |code|
      %i[en fr].each { |locale| I18n.with_locale(locale) { assert_no_match(/translation missing/i, Game::CollectAchievement.failure_message(code)) } }
    end
  end
end
