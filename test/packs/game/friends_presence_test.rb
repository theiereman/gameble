require "test_helper"

# Game::FriendsPresence (CAP-21, AD-24, story 5.3): each friend is doing
# something, online, or away since a time, read from their last-seen time
# and their latest activity; the online count is what menu 04 shows.
class Game::FriendsPresenceTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @now = Time.utc(2026, 10, 7, 15, 0)
    @sam = befriend(accounts_players(:moderator), "Sam")
    @ada = befriend(accounts_players(:administrator), "Ada")
  end

  def befriend(friend, name)
    friend.update_columns(persona_name: name)
    low, high = [ @player.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    friend
  end

  def acted(friend, activity, at)
    Game::PlayerState.where(player_id: friend.id).update_all(last_activity: activity, last_activity_at: at)
  end

  # The online count, which the query and the rows agree on.
  def assert_online(count, now: @now)
    assert_equal count, Game::FriendsPresence.online_count(@player, now:)
    assert_equal count, Game::FriendsPresence.call(@player, now:).count(&:online?)
  end

  def presence = Game::FriendsPresence.call(@player, now: @now).to_h { [ it.player.persona_name, it.to_h.except(:player) ] }

  test "a friend who just acted is active with that activity, online before any last-seen time" do
    acted(@sam, "opening_pack", @now - 1.minute)

    assert_equal({ state: :active, activity: "opening_pack", seen_at: @now - 1.minute }, presence["Sam"])
    assert_online(1)
  end

  test "a friend seen within five minutes is online; one idle past the window is last seen" do
    @sam.update_columns(last_seen_at: @now - 4.minutes)
    @ada.update_columns(last_seen_at: @now - 3.hours)

    assert_equal({ state: :online, activity: nil, seen_at: @now - 4.minutes }, presence["Sam"])
    assert_equal({ state: :offline, activity: nil, seen_at: @now - 3.hours }, presence["Ada"])
    assert_online(1)

    @sam.update_columns(last_seen_at: @now - 5.minutes)
    assert_equal :offline, presence["Sam"][:state]
    assert_online(0)
  end

  test "an activity past its window is no longer shown; the later of both times is the last seen" do
    @sam.update_columns(last_seen_at: @now - 2.hours)
    acted(@sam, "trading", @now - 3.minutes)
    @ada.update_columns(last_seen_at: @now - 1.minute)
    acted(@ada, "trading", @now - 10.minutes)

    assert_equal({ state: :online, activity: nil, seen_at: @now - 3.minutes }, presence["Sam"])
    assert_equal({ state: :online, activity: nil, seen_at: @now - 1.minute }, presence["Ada"])

    assert_online(2)
    travel_to(@now) { assert_equal 2, Game::FriendsPresence.online_count(@player) }
  end

  test "a friend never seen is offline without a time; friends come by name, banned ones left out" do
    banned = accounts_players(:banned)
    low, high = [ @player.id, banned.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    acted(banned, "opening_pack", @now)

    rows = Game::FriendsPresence.call(@player, now: @now)

    assert_equal [ "Ada", "Sam" ], rows.map { it.player.persona_name }
    assert_equal [ [ :offline, nil ] ] * 2, rows.map { [ it.state, it.seen_at ] }
    assert_online(0)
  end

  test "a visitor or a player without friends has none" do
    assert_empty Game::FriendsPresence.call(nil)
    assert_empty Game::FriendsPresence.call(accounts_players(:banned))
    assert_equal 0, Game::FriendsPresence.online_count(nil)
  end
end
