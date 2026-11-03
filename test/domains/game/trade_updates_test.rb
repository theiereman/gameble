require "test_helper"

# The answers to a player's own proposals that they have not opened yet.
class Game::TradeUpdatesTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 10, 7, 15, 0)

  setup do
    @hugo = accounts_players(:player)
    @max = accounts_players(:moderator)
    @eve = accounts_players(:administrator)
  end

  def updates(player = @hugo) = Game::TradeUpdates.call(player, now: NOW)

  def trade(from, to, status: "declined", closed_at: NOW - 1.hour)
    low, high = [ from.id, to.id ].minmax
    Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: from.id, recipient_id: to.id, status:,
      proposed_at: NOW - 3.hours, expires_at: NOW + 1.day, closed_at:)
  end

  def see(trade, player = @hugo, at: NOW)
    Game::TradeView.create!(player_id: player.id, trade_id: trade.id, seen_at: at)
  end

  [ "accepted", "declined" ].each do |status|
    test "a #{status} proposal is an update" do
      answered = trade(@hugo, @max, status:)

      line = updates.sole

      assert_equal answered.token, line.token
      assert_equal status, line.status
      assert Game::TradeUpdates.unseen?(@hugo, answered.token, now: NOW)
    end
  end

  test "the recipient who answered, an open, cancelled or expired trade is no update" do
    trade(@max, @hugo)
    trade(@hugo, @max, status: "open", closed_at: nil)
    trade(@hugo, @max, status: "cancelled")
    trade(@hugo, @eve, status: "expired")

    assert_empty updates
  end

  test "a marker at or after the answer hides it; a marker before it does not" do
    answered = trade(@hugo, @max)
    see(answered, at: answered.closed_at - 1.second)
    assert_equal 1, updates.size

    Game::TradeView.update_all(seen_at: answered.closed_at)
    assert_empty updates
    assert_not Game::TradeUpdates.unseen?(@hugo, answered.token, now: NOW)
  end

  test "the other player's marker hides nothing" do
    answered = trade(@hugo, @max)
    see(answered, @max)

    assert_equal 1, updates.size
  end

  test "an answer older than a week is no update" do
    trade(@hugo, @max, closed_at: NOW - 8.days)

    assert_empty updates
  end

  test "a banned or deleted friend is excluded" do
    trade(@hugo, @max)
    trade(@hugo, @eve)
    @max.update_columns(banned_at: NOW)
    @eve.update_columns(steam_id: nil, persona_name: nil, deleted_at: NOW)

    assert_empty updates
  end

  test "the five most recent come first" do
    answered = Array.new(6) { |index| trade(@hugo, @max, closed_at: NOW - (index + 1).hours) }

    assert_equal answered.first(5).map(&:token), updates.map(&:token)
  end

  test "a visitor has none" do
    assert_empty Game::TradeUpdates.call(nil, now: NOW)
    assert_not Game::TradeUpdates.unseen?(nil, "x", now: NOW)
  end
end
