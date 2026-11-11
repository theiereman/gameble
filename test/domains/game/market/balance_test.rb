require "test_helper"
require_relative "../../../support/market"

class Game::Market::BalanceTest < ActiveSupport::TestCase
  include MarketSettings

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @settings = open_market!
  end

  def post_entry(player, kind, available: 0, committed: 0)
    Game::Market::Ledger.post([ Game::Market::Ledger::Entry.new(player_id: player.id, kind:, available_delta: available, committed_delta: committed, settings_id: @settings.id) ])
  end

  test "a player with no wallet row has nothing available and nothing committed" do
    balance = Game::Market::Balance.call(@alice)

    assert_equal [ 0, 0 ], [ balance.available, balance.committed ]
  end

  test "a wallet posted through the ledger gives both amounts" do
    post_entry(@alice, :mint, available: 43_599)
    post_entry(@alice, :hold, available: -12_000, committed: 12_000)

    balance = Game::Market::Balance.call(@alice)

    assert_equal [ 31_599, 12_000 ], [ balance.available, balance.committed ]
  end

  test "another player's wallet is not read" do
    post_entry(@bob, :mint, available: 5_000)

    assert_equal [ 0, 0 ], Game::Market::Balance.call(@alice).to_h.values
  end
end
