require "test_helper"
require_relative "../../../support/market"

class Game::Market::ReconcileWalletsTest < ActiveSupport::TestCase
  include MarketSettings

  self.use_transactional_tests = false

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    clear
    @settings = open_market!
  end

  teardown { clear }

  def clear
    Game::Market::LedgerEntry.connection.execute("DELETE FROM game_market_ledger_entries")
    Game::Market::Wallet.delete_all
    Game::Market::Settings.connection.execute("DELETE FROM game_market_settings")
  end

  def entry(player, kind, available: 0, committed: 0)
    Game::Market::Ledger::Entry.new(player_id: player.id, kind:, available_delta: available, committed_delta: committed, settings_id: @settings.id)
  end

  def post(*entries) = Game::Market::Ledger.post(entries)

  def reconcile = Game::Market::ReconcileWallets.call

  test "an empty market is balanced with every total at zero" do
    result = reconcile

    assert result.balanced?
    assert_equal [ [], 0, 0, 0 ], [ result.wallet_differences, result.minted, result.destroyed, result.circulation ]
  end

  test "wallets built through the ledger are balanced, with the totals of a real series" do
    Game::Market::Mint.credit(player_id: @alice.id, amount: 10_000, settings_id: @settings.id)
    Game::Market::Mint.credit(player_id: @bob.id, amount: 5_000, settings_id: @settings.id)
    post(entry(@alice, :stamp, available: -500))
    post(entry(@alice, :hold, available: -2_000, committed: 2_000))
    post(entry(@alice, :sale, committed: -2_000), entry(@alice, :commission, available: -100), entry(@bob, :purchase, available: -2_000))
    post(entry(@carol, :sale, available: 1_900), entry(@bob, :forfeit, available: -50))

    result = reconcile

    assert result.balanced?, result.inspect
    assert_equal 15_000, result.minted
    assert_equal 650, result.destroyed
    assert_equal 14_350, result.circulation
  end

  test "a wallet changed outside the ledger is one difference naming the player and both sums" do
    Game::Market::Mint.credit(player_id: @alice.id, amount: 1_000, settings_id: @settings.id)
    Game::Market::Wallet.where(player_id: @alice.id).update_all(available: 1_500)

    result = reconcile

    assert_not result.balanced?
    assert_equal [ Game::Market::Reconciliation::WalletDifference.new(player_id: @alice.id, wallet_available: 1_500, wallet_committed: 0, entries_available: 1_000, entries_committed: 0) ],
      result.wallet_differences
  end

  test "an entry for a player with no wallet is a difference with the wallet at zero" do
    Game::Market::LedgerEntry.insert_all!([ { player_id: @bob.id, kind: "mint", available_delta: 400, committed_delta: 0, settings_id: @settings.id, created_at: Time.current } ])

    difference = reconcile.wallet_differences.sole

    assert_equal [ @bob.id, 0, 0, 400, 0 ], difference.to_h.values
  end

  test "a nonzero wallet with no entries is a difference" do
    Game::Market::Wallet.insert!({ player_id: @carol.id, available: 70, committed: 5 })

    difference = reconcile.wallet_differences.sole

    assert_equal [ @carol.id, 70, 5, 0, 0 ], difference.to_h.values
  end

  test "a circulation off while every wallet matches is a circulation difference without a player" do
    post(entry(@alice, :mint, available: 100), entry(@alice, :stamp, available: -30))
    post(entry(@bob, :purchase, available: 25))

    result = reconcile

    assert_empty result.wallet_differences
    assert_not result.balanced?
    assert_equal 95, result.circulation
    assert_equal 25, result.circulation_difference
  end

  test "a post committed from another thread during the read is not seen" do
    Game::Market::Mint.credit(player_id: @alice.id, amount: 1_000, settings_id: @settings.id)
    interleaved = false
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if interleaved || !payload[:sql].include?("FULL OUTER JOIN")

      interleaved = true
      Thread.new { ActiveRecord::Base.connection_pool.with_connection { post(entry(@bob, :mint, available: 999)) } }.join
    end

    result = reconcile

    assert interleaved
    assert_equal 1_000, result.circulation
    assert_empty result.wallet_differences
    assert_equal 999, Game::Market::Wallet.find_by!(player_id: @bob.id).available
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  test "the read issues no write" do
    Game::Market::Mint.credit(player_id: @alice.id, amount: 1_000, settings_id: @settings.id)
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| statements << payload[:sql] }

    reconcile

    assert_empty statements.grep(/\A\s*(INSERT|UPDATE|DELETE)/i)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
