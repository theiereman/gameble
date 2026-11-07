require "test_helper"

class Game::MarkTradeSeenTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 10, 7, 15, 0)

  setup do
    @hugo = accounts_players(:player)
    @max = accounts_players(:moderator)
    @eve = accounts_players(:administrator)
    low, high = [ @hugo.id, @max.id ].minmax
    @trade = Game::Trade.create!(low_player_id: low, high_player_id: high, proposer_id: @hugo.id, recipient_id: @max.id,
      status: "declined", proposed_at: NOW - 2.hours, expires_at: NOW + 1.day, closed_at: NOW - 1.hour)
  end

  def mark(player = @hugo, token = @trade.token, now: NOW) = Game::MarkTradeSeen.new.call(player:, trade_token: token, now:)

  def seen_at(player = @hugo) = Game::TradeView.find_by(player_id: player.id, trade_id: @trade.id)&.seen_at

  def events = Rails.configuration.event_store.read.of_type([ Game::TradeSeen ]).to_a

  test "either party's marker is written and the answer leaves the updates" do
    assert mark.success?
    assert mark(@max).success?

    assert_equal NOW, seen_at
    assert_equal NOW, seen_at(@max)
    assert_empty Game::TradeUpdates.call(@hugo, now: NOW)
  end

  test "one event is published, with ids and no token" do
    mark

    assert_equal [ { player_id: @hugo.id, trade_id: @trade.id } ], events.map(&:data)
  end

  test "marking twice keeps the later time and leaves one row" do
    mark(now: NOW)
    assert mark(now: NOW - 1.minute).success?
    assert_equal NOW, seen_at

    mark(now: NOW + 1.minute)

    assert_equal NOW + 1.minute, seen_at
    assert_equal 1, Game::TradeView.where(player_id: @hugo.id).count
  end

  test "another pair's trade, an unknown token or no token writes nothing" do
    [ [ @eve, @trade.token ], [ @hugo, "A" * 24 ], [ @hugo, nil ] ].each do |player, token|
      assert_equal Dry::Monads::Failure(:trade_not_found), mark(player, token)
    end

    assert_equal 0, Game::TradeView.count
    assert_empty events
  end

  test "no player is refused" do
    assert_equal Dry::Monads::Failure(:player_required), mark(nil)
  end

  test "releasing a player deletes their markers" do
    mark
    mark(@max)

    assert Game::ReleasePlayer.new.call(player: @hugo).success?

    assert_equal [ @max.id ], Game::TradeView.pluck(:player_id)
  end
end
