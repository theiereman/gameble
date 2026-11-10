require "test_helper"
require_relative "../../support/market"
require_relative "../../support/market_sales"

class Game::ReconcileWalletsJobTest < ActiveSupport::TestCase
  include MarketSales
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
    Game::Market::DailySnapshot.connection.execute("DELETE FROM game_market_daily_snapshots")
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

  test "the edition prices are refreshed after the reconciliation, even when it reports a difference" do
    card = catalog_card_seasons(:common_card_one)
    listing = sold!(card, 10_000, sold_at: 1.day.ago)
    Game::Market::EditionPrice.create!(card_season_id: card.id, average: 99, sales_used: 1)
    Game::Market::Ledger.post([ Game::Market::Ledger::Entry.new(player_id: @alice.id, kind: :purchase, available_delta: 25, settings_id: @settings.id) ])

    assert_error_reported(Game::Market::Reconciliation::CirculationMismatch) { Game::ReconcileWalletsJob.perform_now }

    assert_equal 10_000, Game::Market::EditionPrice.find_by!(card_season_id: card.id).average
  ensure
    listing&.destroy!
    Game::Market::EditionPrice.where(card_season_id: card.id).delete_all
  end

  def snapshots = Game::Market::DailySnapshot.order(:day)

  def backdate_opening!(day) = Game::Market::Settings.connection.execute("DELETE FROM game_market_settings") && open_market!(first_opened_at: day.in_time_zone("UTC"))

  test "the snapshot of the previous UTC day is written with its closing circulation, after the refresh" do
    now = Time.utc(2026, 11, 10, 0, 10)
    settings = backdate_opening!(Date.new(2026, 11, 1))
    Game::Market::LedgerEntry.insert_all!([
      { player_id: @alice.id, kind: "mint", available_delta: 800, committed_delta: 0, settings_id: settings.id, created_at: Time.utc(2026, 11, 9, 15) },
      { player_id: @alice.id, kind: "stamp", available_delta: -100, committed_delta: 0, settings_id: settings.id, created_at: Time.utc(2026, 11, 9, 16) },
      { player_id: @alice.id, kind: "mint", available_delta: 500, committed_delta: 0, settings_id: settings.id, created_at: Time.utc(2026, 11, 10, 0, 5) }
    ])
    Game::Market::Wallet.create!(player_id: @alice.id, available: 1_200)

    Game::ReconcileWalletsJob.perform_now(now:)

    snapshot = snapshots.sole
    assert_equal Date.new(2026, 11, 9), snapshot.day
    assert_equal [ 800, 100, 700 ], snapshot.values_at(:created, :destroyed_total, :circulation)
    assert snapshot.reconciliation_balanced
  end

  test "the snapshot is still written when the reconciliation finds a difference, and says so" do
    now = Time.utc(2026, 11, 10, 0, 10)
    settings = backdate_opening!(Date.new(2026, 11, 1))
    Game::Market::LedgerEntry.insert_all!([ { player_id: @alice.id, kind: "purchase", available_delta: 25, committed_delta: 0, settings_id: settings.id, created_at: Time.utc(2026, 11, 9, 15) } ])
    Game::Market::Wallet.create!(player_id: @alice.id, available: 25)

    assert_error_reported(Game::Market::Reconciliation::CirculationMismatch) { Game::ReconcileWalletsJob.perform_now(now:) }

    snapshot = snapshots.sole
    assert_not snapshot.reconciliation_balanced
    assert_equal [ 0, 25, 25 ], snapshot.values_at(:wallet_differences, :circulation_difference, :circulation)
  end

  test "a second run the same day writes no second snapshot, and no snapshot is written before the opening" do
    now = Time.utc(2026, 11, 10, 0, 10)
    backdate_opening!(Date.new(2026, 11, 1))

    2.times { Game::ReconcileWalletsJob.perform_now(now:) }
    assert_equal 1, snapshots.count

    backdate_opening!(Date.new(2026, 11, 10))
    Game::Market::DailySnapshot.connection.execute("DELETE FROM game_market_daily_snapshots")
    Game::ReconcileWalletsJob.perform_now(now:)
    assert_equal 0, snapshots.count
  end
end
