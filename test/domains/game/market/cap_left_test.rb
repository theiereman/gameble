require "test_helper"
require_relative "../../../support/market"

class Game::Market::CapLeftTest < ActiveSupport::TestCase
  include MarketSettings

  setup do
    @player = accounts_players(:player)
    @settings = open_market!
  end

  test "it is the daily cap less what the player minted today" do
    Game::Market::Ledger.post(Game::Market::Mint.credit(player_id: @player.id, amount: 1_500, settings_id: @settings.id))

    assert_equal 10_500, Game::Market::CapLeft.call(@player.id, settings: @settings)
  end

  test "it is the whole cap before any mint" do
    assert_equal 12_000, Game::Market::CapLeft.call(@player.id, settings: @settings)
  end

  test "it never goes below zero when the cap was lowered under what was minted" do
    Game::Market::Ledger.post(Game::Market::Mint.credit(player_id: @player.id, amount: 5_000, settings_id: @settings.id))
    lowered = open_market!(daily_cap: 3_000)

    assert_equal 0, Game::Market::CapLeft.call(@player.id, settings: lowered)
  end
end
