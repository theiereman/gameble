require "test_helper"
require_relative "../../../support/alt_signal_seeds"

class Game::Market::RefreshAltSignalsTest < ActiveSupport::TestCase
  include AltSignalSeeds

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    Game::Pack.update_all(opened_at: nil)
    @now = Time.utc(2026, 11, 10, 0, 40)
    Game::Market::AltSignal.delete_all
    Game::Market::TiedAccount.delete_all
    @low, @high = [ @alice, @bob ].minmax_by(&:id)
  end

  def refresh(now = @now) = Game::Market::RefreshAltSignals.new.call(now:).value!

  def seed_signals
    (1..3).each { open_capsules!(@alice, 130, on: Date.new(2026, 11, 9) - it) }
    10.times { one_way_trade!(@alice, @bob, closed_at: @now - 2.days) }
  end

  test "every detected signal is stored with its facts and the refresh time" do
    seed_signals

    assert_equal 2, refresh

    rows = Game::Market::AltSignal.order(:signal).to_a
    assert_equal %w[near_maximum_opening one_way_trades], rows.map(&:signal)
    assert_equal [ nil, @bob.id ], rows.map(&:other_account_id)
    assert_equal [ 3, 130 ], rows.first.facts.values_at("days", "peak")
    assert_equal [ @now ], rows.map(&:refreshed_at).uniq
  end

  test "yesterday's rows are dropped when the account no longer matches" do
    Game::Market::AltSignal.create!(account: @bob, signal: "near_maximum_opening", facts: { "days" => 3 }, refreshed_at: 1.day.ago)
    seed_signals

    refresh

    assert_equal [ @alice.id ], Game::Market::AltSignal.pluck(:account_id).uniq
  end

  test "with nothing detected the table is emptied" do
    Game::Market::AltSignal.create!(account: @bob, signal: "near_maximum_opening", facts: {}, refreshed_at: 1.day.ago)

    assert_equal 0, refresh

    assert_equal 0, Game::Market::AltSignal.count
  end

  test "no account, trade, holding or pack changes" do
    seed_signals
    watched = -> { [ Accounts::Player.pluck(:id, :banned_at, :role), Game::Trade.pluck(:id, :status), Game::Holding.pluck(:id, :quantity), Game::Pack.count ] }

    assert_no_changes watched do
      refresh
    end
  end

  test "an unknown signal is refused by the model" do
    assert_raises(ActiveRecord::RecordInvalid) { Game::Market::AltSignal.create!(account: @bob, signal: "other", facts: {}, refreshed_at: @now) }
  end

  test "releasing an account drops the rows that name it" do
    Game::Market::AltSignal.create!(account: @alice, signal: "one_way_trades", other_account: @bob, facts: {}, refreshed_at: @now)
    Game::Market::AltSignal.create!(account: @bob, signal: "near_maximum_opening", facts: {}, refreshed_at: @now)
    Game::Market::TiedAccount.create!(low_account: @low, high_account: @high, signal: "one_way_trades", facts: {}, refreshed_at: @now)

    Game::ReleasePlayer.new.call(player: @bob).value!

    assert_equal 0, Game::Market::AltSignal.count
    assert_equal 0, Game::Market::TiedAccount.count
  end

  test "one-way trades tie the pair once, the lower account id first, with the signal's facts" do
    10.times { one_way_trade!(@high, @low, closed_at: @now - 2.days) }

    refresh

    tie = Game::Market::TiedAccount.sole
    assert_equal [ @low.id, @high.id, "one_way_trades", @now ], [ tie.low_account_id, tie.high_account_id, tie.signal, tie.refreshed_at ]
    assert_equal({ "trades" => 10, "given" => 40, "received" => 10 }, tie.facts)
    assert_equal [ @high.id ], Game::Market::TiedAccounts.call(@low)
    assert_equal [ @low.id ], Game::Market::TiedAccounts.call(@high)
  end

  test "a pair raising one signal both ways is one tie whose facts add up" do
    10.times { one_way_trade!(@high, @low, closed_at: @now - 2.days) }
    10.times { one_way_trade!(@low, @high, closed_at: @now - 2.days) }

    refresh

    assert_equal({ "trades" => 20, "given" => 80, "received" => 20 }, Game::Market::TiedAccount.sole.facts)
  end

  test "a single-account signal ties nobody" do
    (1..3).each { open_capsules!(@alice, 130, on: Date.new(2026, 11, 9) - it) }

    refresh

    assert_equal 0, Game::Market::TiedAccount.count
    assert_empty Game::Market::TiedAccounts.call(@alice)
  end

  test "a deleted account's pair is not tied" do
    10.times { one_way_trade!(@alice, @bob, closed_at: @now - 2.days) }
    @bob.update_columns(deleted_at: @now, steam_id: nil)

    refresh

    assert_equal 0, Game::Market::TiedAccount.count
  end

  test "a second refresh replaces the ties" do
    10.times { one_way_trade!(@alice, @bob, closed_at: @now - 2.days) }
    refresh

    refresh(@now + 1.day)

    assert_equal [ @now + 1.day ], Game::Market::TiedAccount.pluck(:refreshed_at)

    refresh(@now + 10.days)

    assert_equal 0, Game::Market::TiedAccount.count
  end

  test "the database refuses a tie with the higher account id first" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Game::Market::TiedAccount.create!(low_account: @high, high_account: @low, signal: "one_way_trades", facts: {}, refreshed_at: @now)
    end
  end

  test "the job queues on default and runs the refresh" do
    assert_equal "default", Game::RefreshAltSignalsJob.new.queue_name
    seed_signals

    Game::RefreshAltSignalsJob.perform_now(now: @now)

    assert_equal 2, Game::Market::AltSignal.count
  end
end
