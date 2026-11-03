require "test_helper"
require_relative "../../support/game_packs"

# The bell's lines, from current state: the friend requests received, the
# trades waiting on the player, the daily capsule while collectable, and the
# weekly mission, its reward line while a reward waits.
class Game::BellItemsTest < ActiveSupport::TestCase
  include GamePacks

  NOW = Time.utc(2026, 10, 7, 15, 0)

  setup do
    @hugo = accounts_players(:player)
    @max = accounts_players(:moderator)
    @eve = accounts_players(:administrator)
  end

  def items(player = @hugo, now: NOW) = Game::BellItems.call(player, now:)

  def invite(from, to, status: "pending")
    Game::Invitation.create!(sender_id: from.id, recipient_id: to.id, status:)
  end

  def trade(from, to, status: "open", proposed_at: NOW - 1.hour, expires_at: NOW + 1.day)
    low, high = [ from.id, to.id ].minmax
    Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: from.id, recipient_id: to.id, status:, proposed_at:, expires_at:)
  end

  test "a trade waiting on the player is a line with its token, its proposer and its revision" do
    waiting = trade(@max, @hugo)

    line = items.trades.sole

    assert_equal waiting.token, line.token
    assert_equal @max, line.player
    assert_equal waiting.revision, line.revision
  end

  test "a trade waiting on the friend, closed, expired or from a banned proposer is no line" do
    trade(@hugo, @max)
    trade(@max, @hugo, status: "declined")
    trade(@max, @hugo, expires_at: NOW - 1.minute)
    trade(@eve, @hugo)
    @eve.update_columns(banned_at: NOW)

    assert_empty items.trades
  end

  test "a trade countered back to the player comes with its new revision" do
    waiting = trade(@max, @hugo)
    before = items.trades.sole.revision

    waiting.update!(proposed_at: NOW - 1.minute)

    assert_not_equal before, items.trades.sole.revision
  end

  test "a pending request received is a line with its token and its sender; sent, answered or banned ones are not" do
    received = invite(@max, @hugo)
    invite(@hugo, @eve)
    invite(@eve, @hugo, status: "ignored")

    line = items.invitations.sole
    assert_equal received.token, line.token
    assert_equal @max, line.player

    @max.update_columns(banned_at: NOW)
    assert_empty items.invitations
  end

  test "each kind holds five lines at most: the trades expiring soonest, the newest requests" do
    players = Array.new(6) { |index| Accounts::Player.create!(steam_id: "7656119800000#{format("%04d", index)}") }
    trades = players.each_with_index.map { |player, index| trade(player, @hugo, expires_at: NOW + (6 - index).hours) }
    invitations = players.map { |player| invite(player, @hugo) }

    assert_equal trades.reverse.first(5).map(&:token), items.trades.map(&:token)
    assert_equal invitations.reverse.first(5).map(&:token), items.invitations.map(&:token)
  end

  test "the daily capsule is a line for the day while it is collectable" do
    assert_equal NOW.to_date, items.daily

    Game::DailyBonusClaim.create!(player_id: @hugo.id, day: NOW.to_date, pack_id: create_pack(@hugo, kind: :bonus).id)
    assert_nil items.daily

    assert_equal NOW.to_date + 1, items(now: NOW + 1.day).daily
  end

  test "with no published season there is no daily line" do
    without_published_season { assert_nil items.daily }
  end

  test "the mission line is the week's, with its target, while no reward waits" do
    Game::WeeklyGoal.create!(week_start: Date.new(2026, 10, 5), total: 40, target: 600)

    goal = items.goal

    assert_equal Date.new(2026, 10, 5), goal.week_start
    assert_not goal.reward_ready
    assert_equal 600, goal.target
    assert_not goal.reached
  end

  test "the week's line knows once the mission is accomplished" do
    Game::WeeklyGoal.create!(week_start: Date.new(2026, 10, 5), total: 600, target: 600)

    assert items.goal.reached
  end

  test "an unclaimed reward replaces the week's line; once claimed, the week's line comes back" do
    reward = Game::GoalReward.create!(player_id: @hugo.id, week_start: Date.new(2026, 9, 28))

    goal = items.goal
    assert goal.reward_ready
    assert_equal Date.new(2026, 9, 28), goal.week_start

    reward.update_columns(pack_id: create_pack(@hugo, kind: :reward).id)
    assert_not items.goal.reward_ready
  end
end
