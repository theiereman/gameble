require "test_helper"

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

  test "one friend's presence reads as their row does" do
    acted(@sam, "trading", @now - 1.minute)
    @ada.update_columns(last_seen_at: @now - 3.hours)

    assert_equal presence["Sam"], Game::FriendsPresence.of(@sam, now: @now).to_h.except(:player)
    assert_equal presence["Ada"], Game::FriendsPresence.of(@ada, now: @now).to_h.except(:player)
  end

  test "a deleted friend still in a friendship row is neither listed nor counted online" do
    acted(@sam, "opening_pack", @now)
    @sam.update_columns(steam_id: nil, deleted_at: @now)

    assert_equal [ "Ada" ], Game::FriendsPresence.call(@player, now: @now).map { it.player.persona_name }
    assert_online(0)
  end

  test "a private friend reads as private, without activity or seen time, and is never counted online" do
    acted(@sam, "opening_pack", @now - 1.minute)
    @sam.update_columns(last_seen_at: @now, visibility: "private")
    @ada.update_columns(last_seen_at: @now)

    assert_equal({ state: :private, activity: nil, seen_at: nil }, presence["Sam"])
    assert_equal presence["Sam"], Game::FriendsPresence.of(@sam, now: @now).to_h.except(:player)
    assert_online(1)
  end

  test "a friends-only friend shows their presence as before" do
    acted(@sam, "opening_pack", @now - 1.minute)
    @sam.update_columns(visibility: "friends_only")

    assert_equal :active, presence["Sam"][:state]
    assert_online(1)
  end

  test "a visitor or a player without friends has none" do
    assert_empty Game::FriendsPresence.call(nil)
    assert_empty Game::FriendsPresence.call(accounts_players(:banned))
    assert_equal 0, Game::FriendsPresence.online_count(nil)
  end
end
