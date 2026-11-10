require "test_helper"
require_relative "../../../support/alt_signal_seeds"

class Game::Market::AltSignalsTest < ActiveSupport::TestCase
  include AltSignalSeeds

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    Game::Pack.update_all(opened_at: nil)
    @now = Time.utc(2026, 11, 10, 0, 40)
    @yesterday = Date.new(2026, 11, 9)
  end

  def detected(signal = nil)
    found = Game::Market::AltSignals.call(now: @now)
    signal ? found.select { it.signal == signal } : found
  end

  test "120 capsules a day on 3 of the last 7 days is near-maximum opening, with its facts" do
    [ 1, 3, 5 ].each { open_capsules!(@alice, 120, on: @yesterday - it) }
    open_capsules!(@alice, 130, on: @yesterday)

    found = detected("near_maximum_opening")

    assert_equal 1, found.size
    assert_equal @alice.id, found.first.account_id
    assert_nil found.first.other_account_id
    assert_equal({ "days" => 4, "peak" => 130, "per_day" => 120 }, found.first.facts)
  end

  test "119 capsules a day, or 120 on only 2 days, is not a signal" do
    [ 1, 2, 3 ].each { open_capsules!(@alice, 119, on: @yesterday - it) }
    [ 0, 1 ].each { open_capsules!(@bob, 120, on: @yesterday - it) }

    assert_empty detected("near_maximum_opening")
  end

  test "a day older than the 7 complete days and the day not yet over are not counted" do
    open_capsules!(@alice, 120, on: @yesterday - 7)
    open_capsules!(@alice, 120, on: @yesterday - 1)
    open_capsules!(@alice, 120, on: @yesterday)
    open_capsules!(@alice, 120, on: @now.to_date)

    assert_empty detected("near_maximum_opening")
  end

  test "10 trades giving 4 for 1 in 7 days are one-way, naming the receiver" do
    10.times { one_way_trade!(@alice, @bob, closed_at: @now - 2.days) }
    one_way_trade!(@alice, @bob, closed_at: @now - 8.days)

    found = detected("one_way_trades")

    assert_equal [ [ @alice.id, @bob.id ] ], found.map { [ it.account_id, it.other_account_id ] }
    assert_equal({ "trades" => 10, "given" => 40, "received" => 10 }, found.first.facts)
  end

  test "the giver is the account when the recipient gives" do
    10.times { trade!(@alice, @bob, offered: 1, requested: 4, closed_at: @now - 1.day) }

    assert_equal [ [ @bob.id, @alice.id ] ], detected("one_way_trades").map { [ it.account_id, it.other_account_id ] }
  end

  test "9 one-way trades, trades giving 3 for 1, and trades not accepted are not a signal" do
    9.times { one_way_trade!(@alice, @bob, closed_at: @now - 1.day) }
    10.times { trade!(@bob, @alice, offered: 3, requested: 1, closed_at: @now - 1.day) }
    10.times { trade!(@alice, @bob, offered: 4, requested: 1, closed_at: @now - 1.day, status: "declined") }

    assert_empty detected("one_way_trades")
  end

  test "detection writes nothing" do
    10.times { one_way_trade!(@alice, @bob, closed_at: @now - 1.day) }

    assert_no_difference -> { Game::Trade.count + Game::TradeItem.count + Game::Holding.count + Game::Pack.count } do
      detected
    end
  end
end
