require "test_helper"
require_relative "../../../support/market"

class Game::Market::MintedTodayTest < ActiveSupport::TestCase
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @settings = open_market!
    @now = Time.utc(2026, 11, 10, 12)
  end

  def post(kind, amount, player: @player)
    Game::Market::Ledger.post([ Game::Market::Ledger::Entry.new(player_id: player.id, kind:, available_delta: amount, settings_id: @settings.id) ])
  end

  test "it sums the mint entries of the player since 00:00 UTC" do
    travel_to(@now) do
      post(:mint, 3_000)
      post(:mint, 2_000)
      assert_equal 5_000, Game::Market::MintedToday.call(@player.id)
    end
  end

  test "it ignores other kinds and other players" do
    travel_to(@now) do
      post(:sale, 9_000)
      post(:mint, 7_000, player: accounts_players(:moderator))
      assert_equal 0, Game::Market::MintedToday.call(@player.id)
    end
  end

  test "it ignores entries of the day before and of the day after" do
    travel_to(Time.utc(2026, 11, 9, 23, 59, 59)) { post(:mint, 4_000) }
    travel_to(Time.utc(2026, 11, 10, 0, 0, 0)) { post(:mint, 1_000) }

    assert_equal 1_000, Game::Market::MintedToday.call(@player.id, now: @now)
    assert_equal 0, Game::Market::MintedToday.call(@player.id, now: Time.utc(2026, 11, 11, 0, 0, 0))
  end
end
