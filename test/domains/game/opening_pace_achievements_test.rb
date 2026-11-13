require "test_helper"
require_relative "../../support/game_packs"

class Game::OpeningPaceAchievementsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
  end

  def grant(key, player: @player) = Game::GrantAchievement.new.call(player:, achievement: key)
  def unlocked(player = @player) = Game::AchievementUnlock.where(player_id: player.id).pluck(:achievement)
  def metric(name, player = @player) = Game::AchievementProgress.call(player, [ name ]).fetch(name)

  def opened_at(times, player: @player)
    times.each { create_pack(player, opened_at: it) }
  end

  def opened_at_local_hours(hours, player: @player)
    hours.each { create_pack(player, opened_at: Time.current).update_columns(opened_local_hour: it) }
  end

  def seconds_apart(count, gap, from: Time.utc(2026, 1, 1)) = Array.new(count) { from + (it * gap).seconds }

  test "the two opening pace achievements follow each other in the catalogue, each earned once" do
    expected = [ [ :no_time_to_waste, :quick_capsule_bursts, 1 ], [ :night_owl, :night_capsules, 1 ] ]
    first = Game::Achievements::CATALOGUE.index { it.key == :no_time_to_waste }

    assert_equal expected, Game::Achievements::CATALOGUE[first, 2].map { [ it.key, it.metric, it.threshold ] }
  end

  test "ten capsules opened within 29 seconds grant No Time to Waste" do
    opened_at(seconds_apart(10, 3.2))

    assert_equal 1, metric(:quick_capsule_bursts)
    assert_equal :no_time_to_waste, grant(:no_time_to_waste).value!.key
  end

  test "ten capsules spanning exactly 30 seconds are not fast enough, nor are nine in five" do
    opened_at(seconds_apart(9, 3) + [ Time.utc(2026, 1, 1, 0, 0, 30) ])
    opened_at(seconds_apart(9, 0.5, from: Time.utc(2026, 2, 1)), player: @other)

    assert_equal 0, metric(:quick_capsule_bursts)
    assert_equal :not_reached, grant(:no_time_to_waste).failure
    assert_equal :not_reached, grant(:no_time_to_waste, player: @other).failure
  end

  test "any ten consecutive capsules count, wherever they fall among slower openings; unopened ones and other players' are ignored" do
    slow = seconds_apart(5, 60)
    opened_at(slow + seconds_apart(10, 2, from: slow.last + 5.minutes) + seconds_apart(3, 60, from: Time.utc(2026, 3, 1)))
    create_pack(@player)
    opened_at(seconds_apart(5, 1, from: Time.utc(2026, 4, 1)), player: @other)

    assert_equal 1, metric(:quick_capsule_bursts)
    assert_equal 0, metric(:quick_capsule_bursts, @other)
  end

  test "a capsule opened from 1:00 to 3:59 in the player's local time grants Night Owl; 0:59 and 4:00 do not" do
    opened_at_local_hours([ 0, 4, 23, nil ])
    assert_equal 0, metric(:night_capsules)
    assert_equal :not_reached, grant(:night_owl).failure

    opened_at_local_hours([ 3 ], player: @other)
    assert_equal :night_owl, grant(:night_owl, player: @other).value!.key
  end

  test "an opening records the hour in the time zone it is given, and none without one" do
    travel_to Time.utc(2026, 7, 1, 0, 30) do
      2.times { create_pack(@player) }
      Game::OpenPack.new.call(player: @player, time_zone: ActiveSupport::TimeZone["Europe/Paris"]).value!
      Game::OpenPack.new.call(player: @player).value!
    end

    assert_equal [ 2, nil ], Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).order(:id).pluck(:opened_local_hour)
  end

  test "opening a capsule at 2 AM local time grants Night Owl through the opening's jobs" do
    travel_to Time.utc(2026, 1, 15, 7, 10) do
      create_pack(@player)
      perform_enqueued_jobs { Game::OpenPack.new.call(player: @player, time_zone: ActiveSupport::TimeZone["America/New_York"]).value! }
    end

    assert_includes unlocked, "night_owl"
  end
end
