require "test_helper"
require_relative "../../../support/game_packs"
require_relative "../../../support/market"
require_relative "../../../support/market_sales"

class Game::Market::WriteDailySnapshotTest < ActiveSupport::TestCase
  include GamePacks
  include MarketSales
  include MarketSettings

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    Game::Market::LedgerEntry.connection.execute("DELETE FROM game_market_ledger_entries")
    Game::Market::Wallet.delete_all
    Game::Pack.update_all(opened_at: nil)
    @settings = open_market!(first_opened_at: Date.new(2026, 11, 1).in_time_zone("UTC"))
    @first = Date.new(2026, 11, 3)
  end

  def entry!(player, kind, amount, day, hour: 12)
    Game::Market::LedgerEntry.insert_all!([ { player_id: player.id, kind:, available_delta: amount, committed_delta: 0, settings_id: @settings.id,
      created_at: day.in_time_zone("UTC") + hour.hours } ])
  end

  def opened!(player, day) = create_pack(player, opened_at: day.in_time_zone("UTC") + 8.hours)

  def circulation_before(day) = Game::Market::LedgerEntry.where(created_at: ...day.in_time_zone("UTC")).sum("available_delta + committed_delta")

  def write(day, **) = Game::Market::WriteDailySnapshot.new.call(day:, circulation: circulation_before(day + 1), **).value!

  def events = Rails.configuration.event_store.read.stream(Game::Market::DailySnapshotWritten::STREAM).of_type(Game::Market::DailySnapshotWritten).to_a

  test "a day's flows, active players, earnings and top share are written" do
    entry!(@alice, "mint", 10_000, @first)
    entry!(@bob, "mint", 6_000, @first)
    entry!(@alice, "stamp", -1_000, @first)
    entry!(@bob, "commission", -600, @first)
    entry!(@bob, "sale", 9_000, @first)
    entry!(@carol, "forfeit", -400, @first)
    entry!(@carol, "mint", 500, @first - 1)
    opened!(@alice, @first)
    opened!(@bob, @first)

    snapshot = write(@first)

    assert_equal [ 16_000, 2_000, 400 ], snapshot.values_at(:created, :destroyed, :forfeited)
    assert_equal 23_500, snapshot.circulation
    assert_equal 2, Game::Market::DailyFigures.active_players(@first.in_time_zone("UTC") + 1.day, 90.days)
    assert_equal 11_750, snapshot.picoins_per_active_player
    assert_equal 12_200, snapshot.median_daily_earnings
    assert snapshot.reconciliation_balanced
    assert_equal @first, snapshot.day
  end

  test "the median ignores inactive players and zero earnings, and is null with none" do
    entry!(@alice, "mint", 5_000, @first)
    entry!(@bob, "mint", 9_000, @first)
    entry!(@carol, "mint", 100, @first)
    entry!(@carol, "commission", -100, @first)
    opened!(@alice, @first)
    opened!(@carol, @first)

    assert_equal 5_000, write(@first).median_daily_earnings
    assert_nil write(@first + 1).median_daily_earnings
  end

  test "an even count of earners gives the mean of the two middle ones" do
    entry!(@alice, "mint", 5_000, @first)
    entry!(@bob, "mint", 8_000, @first)
    opened!(@alice, @first)
    opened!(@bob, @first)

    assert_equal 6_500, write(@first).median_daily_earnings
  end

  test "each day's circulation is the previous one plus created less destroyed" do
    entry!(@alice, "mint", 10_000, @first)
    entry!(@alice, "stamp", -1_000, @first)
    entry!(@bob, "mint", 4_000, @first + 1, hour: 3)
    entry!(@bob, "commission", -500, @first + 1, hour: 20)
    entry!(@carol, "forfeit", -700, @first + 2)
    entry!(@carol, "mint", 300, @first + 2)

    days = (@first..(@first + 3)).map { write(it) }

    days.each_cons(2) { |before, after| assert_equal before.circulation + after.created - after.destroyed, after.circulation }
    assert_equal [ 9_000, 12_500, 12_100, 12_100 ], days.map(&:circulation)
    assert_equal 12_100, circulation_before(@first + 4)
  end

  test "a rarity's price is the median of its editions with enough sales, null with none" do
    first = catalog_card_seasons(:common_card_one)
    second = catalog_card_seasons(:uncommon_card_one)
    second.update_columns(rarity: 1)
    Game::Market::EditionPrice.create!(card_season_id: first.id, average: 1_000, sales_used: 3)
    Game::Market::EditionPrice.create!(card_season_id: second.id, average: 2_000, sales_used: 5)
    Game::Market::EditionPrice.create!(card_season_id: catalog_card_seasons(:rare_card_one).id, average: 9_000, sales_used: 2)

    snapshot = write(@first)

    assert_equal 1_500, snapshot.average_price_common
    assert_nil snapshot.average_price_rare
    assert_nil snapshot.average_price_legendary
  end

  test "a second run for the day changes nothing and publishes nothing" do
    entry!(@alice, "mint", 10_000, @first)

    first = write(@first)
    entry!(@alice, "mint", 5_000, @first)

    assert_nil write(@first)
    assert_equal [ first.id ], Game::Market::DailySnapshot.pluck(:id)
    assert_equal 10_000, Game::Market::DailySnapshot.find(first.id).created
    assert_equal 1, events.size
  end

  test "a day before the market first opened writes nothing, and so does a market with no settings" do
    assert_nil write(Date.new(2026, 10, 31))
    Game::Market::LedgerEntry.connection.execute("DELETE FROM game_market_ledger_entries")
    Game::Market::Settings.connection.execute("DELETE FROM game_market_settings")

    assert_nil write(@first)
    assert_equal 0, Game::Market::DailySnapshot.count
    assert_empty events
  end

  test "the day of the first opening is written" do
    assert_not_nil write(Date.new(2026, 11, 1))
  end

  test "the reconciliation's result is kept" do
    snapshot = write(@first, balanced: false, wallet_differences: 2, circulation_difference: 25)

    assert_not snapshot.reconciliation_balanced
    assert_equal [ 2, 25 ], snapshot.values_at(:wallet_differences, :circulation_difference)
  end

  test "nothing minted and nobody active leaves the optional figures null" do
    snapshot = write(@first)

    assert_equal [ 0, 0, 0, 0 ], snapshot.values_at(:created, :destroyed, :forfeited, :circulation)
    assert_nil snapshot.picoins_per_active_player
    assert_nil snapshot.median_daily_earnings
    assert_nil snapshot.top_share_basis_points
  end

  test "the top share is the richest hundredth of the wallets holding PiCoins" do
    players = Accounts::Player.order(:id).limit(3).to_a
    Game::Market::Ledger.post(players.zip([ 700, 200, 100 ]).map { |player, amount| Game::Market::Ledger::Entry.new(player_id: player.id, kind: :mint, available_delta: amount, settings_id: @settings.id) })

    assert_equal 7_000, write(@first).top_share_basis_points
  end
end
