require "test_helper"

class Accounts::ReportQueueTest < ActiveSupport::TestCase
  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
  end

  def stranger(number) = Accounts::Player.create!(steam_id: "7656119796034#{number.to_s.rjust(4, "0")}")

  def report(reported, reporter, reason, at:, handled: false)
    Accounts::Report.create!(reporter:, reported:, reason:, created_at: at, handled_at: (at if handled))
  end

  test "one row per player in good standing with open reports, the latest open report first, with the counts per reason" do
    reporters = (1..4).map { stranger(it) }
    report(@alice, reporters[0], "cheating", at: 3.hours.ago)
    report(@alice, reporters[1], "cheating", at: 2.hours.ago)
    report(@alice, reporters[2], "other", at: 5.hours.ago)
    report(@alice, reporters[3], "harassment", at: 10.minutes.ago, handled: true)
    report(@bob, reporters[0], "inappropriate_name", at: 1.hour.ago)
    report(@carol, reporters[0], "cheating", at: 1.minute.ago, handled: true)
    report(accounts_players(:banned), reporters[0], "cheating", at: 1.minute.ago)
    deleted = stranger(5)
    report(deleted, reporters[0], "cheating", at: 1.minute.ago)
    Accounts::DeletePlayer.new.call(player: deleted).value!

    players = Accounts::ReportQueue.players
    rows = Accounts::ReportQueue.rows(players)

    assert_equal [ @bob, @alice ], players.to_a
    assert_equal 2, players.count
    assert_equal 2, Accounts::ReportQueue.size
    bob, alice = rows
    assert_equal({ "inappropriate_name" => 0, "cheating" => 2, "harassment" => 0, "other" => 1 }, alice.counts)
    assert_equal 3, alice.total
    assert_in_delta 2.hours.ago, alice.latest_at, 1
    assert_equal({ "inappropriate_name" => 1, "cheating" => 0, "harassment" => 0, "other" => 0 }, bob.counts)
    assert_equal 1, bob.total
  end

  test "a page of the queue is read in its order" do
    report(@alice, stranger(1), "cheating", at: 2.hours.ago)
    report(@bob, stranger(2), "cheating", at: 1.hour.ago)

    assert_equal [ @alice ], Accounts::ReportQueue.rows(Accounts::ReportQueue.players.offset(1).limit(1)).map(&:player)
  end

  test "a player whose reports were handled after the page was read is skipped" do
    report(@alice, stranger(1), "cheating", at: 2.hours.ago)
    report(@bob, stranger(2), "cheating", at: 1.hour.ago)
    page = Accounts::ReportQueue.players.to_a

    Accounts::Report.where(reported: @bob).update_all(handled_at: Time.current)

    assert_equal [ @alice ], Accounts::ReportQueue.rows(page).map(&:player)
  end

  test "an empty queue" do
    assert_empty Accounts::ReportQueue.players
    assert_equal 0, Accounts::ReportQueue.size
    assert_empty Accounts::ReportQueue.rows(Accounts::ReportQueue.players)
  end

  test "the banned players whose accounts remain, the latest ban first" do
    banned = accounts_players(:banned)
    @alice.update!(banned_at: 1.hour.ago)
    deleted = stranger(6)
    Accounts::DeletePlayer.new.call(player: deleted).value!
    deleted.update_columns(banned_at: Time.current)

    assert_equal [ @alice, banned ], Accounts::BannedPlayers.call.to_a
  end
end
