require "test_helper"

class Accounts::PurgeReportsTest < ActiveSupport::TestCase
  setup do
    @now = Time.current.change(usec: 0)
    @reported = accounts_players(:player)
    @reporters = 0
  end

  def purge(limit: 1000) = Accounts::PurgeReports.new.call(now: @now, limit:).value!

  def report(reported: @reported, handled_at: nil, created_at: @now - 2.years)
    @reporters += 1
    reporter = Accounts::Player.create!(steam_id: "7656119796040#{@reporters.to_s.rjust(4, "0")}")
    Accounts::Report.create!(reporter:, reported:, reason: :cheating, handled_at:, created_at:)
  end

  def deleted_player(steam_id, ago)
    Accounts::Player.create!(steam_id:).tap { it.update_columns(steam_id: nil, deleted_at: @now - ago) }
  end

  test "a report handled a year and a second ago is purged; one handled a second short of a year is kept" do
    old = report(handled_at: @now - 1.year - 1.second)
    recent = report(handled_at: @now - 1.year + 1.second)

    assert_equal 1, purge
    assert_not Accounts::Report.exists?(old.id)
    assert Accounts::Report.exists?(recent.id)
  end

  test "an open report against a player in good standing is kept, however old" do
    open = report(created_at: @now - 5.years)

    assert_equal 0, purge
    assert Accounts::Report.exists?(open.id)
  end

  test "an open report against an account deleted a year and a second ago is purged; a second short of a year, kept" do
    old = report(reported: deleted_player("76561197960410001", 1.year + 1.second))
    recent = report(reported: deleted_player("76561197960410002", 1.year - 1.second))

    assert_equal 1, purge
    assert_not Accounts::Report.exists?(old.id)
    assert Accounts::Report.exists?(recent.id)
  end

  test "at most the limit per call, and nothing once all is purged" do
    3.times { report(handled_at: @now - 2.years) }

    assert_equal [ 2, 1, 0 ], Array.new(3) { purge(limit: 2) }
  end

  test "no event is published" do
    report(handled_at: @now - 2.years)

    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      assert_equal 1, purge
    end
  end
end
