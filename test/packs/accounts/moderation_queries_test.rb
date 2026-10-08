require "test_helper"

class Accounts::ModerationQueriesTest < ActiveSupport::TestCase
  setup do
    @reporter = accounts_players(:player)
    @first = accounts_players(:moderator)
    @second = accounts_players(:administrator)
  end

  def report(reported, reason, at, reporter: @reporter)
    Accounts::Report.create!(reporter:, reported:, reason:, created_at: at)
  end

  test "the queue holds the reports on players in good standing, the latest first, with both players loaded" do
    older = report(@first, "cheating", 2.days.ago)
    newer = report(@second, "harassment", 1.hour.ago)
    other = report(@first, "other", 1.day.ago, reporter: @second)
    report(accounts_players(:banned), "cheating", 1.minute.ago)
    deleted = Accounts::Player.create!(steam_id: "76561197960287911")
    report(deleted, "other", 1.minute.ago)
    Accounts::DeletePlayer.new.call(player: deleted).value!

    queue = Accounts::ReportQueue.call(viewer: accounts_players(:player))

    assert_equal [ newer, other, older ], queue
    assert queue.all? { it.association(:reporter).loaded? && it.association(:reported).loaded? }
  end

  test "the queue leaves out the reports on the staff member reading it" do
    on_viewer = report(@first, "cheating", 2.hours.ago)
    other = report(@second, "other", 1.hour.ago)

    assert_equal [ other ], Accounts::ReportQueue.call(viewer: @first)
    assert_equal [ other, on_viewer ], Accounts::ReportQueue.call(viewer: @reporter)
  end

  test "the banned players are the banned accounts not deleted, the latest ban first" do
    banned = accounts_players(:banned)
    @first.update_columns(banned_at: 1.hour.ago)

    assert_equal [ @first, banned ], Accounts::BannedPlayers.call
  end
end
