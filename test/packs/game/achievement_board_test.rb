require "test_helper"
require_relative "../../support/game_packs"

class Game::AchievementBoardTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
  end

  def unlock(*keys, player: @player)
    keys.each { |key| Game::AchievementUnlock.create!(player_id: player.id, achievement: key, unlocked_at: Time.current) }
  end

  def opened_packs(count, player: @player)
    count.times { create_pack(player, opened_at: Time.current) }
  end

  def tile(key, player = @player) = Game::AchievementBoard.call(player).find { it.key == key }

  test "a tile per achievement, in catalogue order, each with its threshold" do
    tiles = Game::AchievementBoard.call(@player)

    assert_equal Game::Achievements::CATALOGUE.map(&:key), tiles.map(&:key)
    assert_equal Game::Achievements::CATALOGUE.map(&:threshold), tiles.map(&:threshold)
  end

  test "a visitor gets every tile unearned at zero, and a summary of nothing earned" do
    tiles = Game::AchievementBoard.call(nil)

    assert tiles.none?(&:earned)
    assert tiles.all? { it.progress.zero? }
    assert_equal({ earned: 0, total: 10 }, Game::AchievementBoard.summary(nil))
  end

  test "a tile is earned when its unlock row exists, and the summary counts those rows" do
    unlock("first_booster", "first_trade", "boosters_10")
    unlock("first_epic", player: accounts_players(:moderator))

    assert_equal %i[first_booster first_trade boosters_10], Game::AchievementBoard.call(@player).select(&:earned).map(&:key)
    assert_equal({ earned: 3, total: 10 }, Game::AchievementBoard.summary(@player))
  end

  test "progress is the metric clamped to the threshold, earned or not" do
    opened_packs(12)

    assert_equal [ 1, 10, 12, 12 ], %i[first_booster boosters_10 boosters_100 boosters_500].map { tile(it).progress }
    assert_not tile(:boosters_10).earned
  end

  test "only an achievement with a threshold above one is countable" do
    assert_equal %i[boosters_10 boosters_100 boosters_500 three_complete_sets],
      Game::AchievementBoard.call(@player).select(&:countable?).map(&:key)
  end

  test "an unlock row whose key the catalogue no longer holds is ignored" do
    unlock("first_booster", "retired_achievement")

    assert_equal({ earned: 1, total: 10 }, Game::AchievementBoard.summary(@player))
    assert_equal 1, Game::AchievementBoard.call(@player).count(&:earned)
  end
end
