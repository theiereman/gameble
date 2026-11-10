require "test_helper"
require_relative "../../support/market"

class Game::ReconcileWalletsJobTest < ActiveSupport::TestCase
  include MarketSettings

  self.use_transactional_tests = false

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    clear
    @settings = open_market!
  end

  teardown { clear }

  def clear
    Game::Market::LedgerEntry.connection.execute("DELETE FROM game_market_ledger_entries")
    Game::Market::Wallet.delete_all
    Game::Market::Settings.connection.execute("DELETE FROM game_market_settings")
  end

  def wallet(player) = Game::Market::Wallet.find_by(player_id: player.id)

  test "matching wallets report nothing and no balance changes" do
    Game::Market::Mint.credit(player_id: @alice.id, amount: 1_000, settings_id: @settings.id)

    assert_no_error_reported { Game::ReconcileWalletsJob.perform_now }

    assert_equal 1_000, wallet(@alice).available
  end

  test "a wallet changed outside the ledger is reported with its player and left as it was" do
    Game::Market::Mint.credit(player_id: @alice.id, amount: 1_000, settings_id: @settings.id)
    Game::Market::Wallet.where(player_id: @alice.id).update_all(available: 1_500)

    report = assert_error_reported(Game::Market::Reconciliation::WalletMismatch) { Game::ReconcileWalletsJob.perform_now }

    assert_equal [ @alice.id, 1_500, 1_000 ], report.context.values_at(:player_id, :wallet_available, :entries_available)
    assert_equal 1_500, wallet(@alice).available
  end

  test "an entry for a player with no wallet is reported with that player" do
    Game::Market::LedgerEntry.insert_all!([ { player_id: @bob.id, kind: "mint", available_delta: 400, committed_delta: 0, settings_id: @settings.id, created_at: Time.current } ])

    report = assert_error_reported(Game::Market::Reconciliation::WalletMismatch) { Game::ReconcileWalletsJob.perform_now }

    assert_equal @bob.id, report.context[:player_id]
  end

  test "a circulation difference is reported once, with the totals" do
    Game::Market::Ledger.post([ Game::Market::Ledger::Entry.new(player_id: @alice.id, kind: :purchase, available_delta: 25, settings_id: @settings.id) ])

    report = assert_error_reported(Game::Market::Reconciliation::CirculationMismatch) { Game::ReconcileWalletsJob.perform_now }

    assert_equal [ 25, 0, 0, 25 ], report.context.values_at(:circulation, :minted, :destroyed, :difference)
  end

  test "the job returns the reconciliation" do
    result = Game::ReconcileWalletsJob.perform_now

    assert_instance_of Game::Market::Reconciliation, result
    assert result.balanced?
  end
end
