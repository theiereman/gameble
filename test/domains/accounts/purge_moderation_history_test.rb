require "test_helper"

class Accounts::PurgeModerationHistoryTest < ActiveSupport::TestCase
  setup do
    @now = Time.current.change(usec: 0)
    @moderator = accounts_players(:moderator)
    @player = accounts_players(:player)
    @banned = accounts_players(:banned)
  end

  def purge(limit: 500) = Accounts::PurgeModerationHistory.new.call(now: @now, limit:).value!

  def action(kind, ago, player: @player, reason: nil)
    reason ||= "Spam" if kind == :ban
    Accounts::ModerationAction.create!(kind:, player:, staff: @moderator, reason:, created_at: @now - ago)
  end

  def kept?(row) = Accounts::ModerationAction.exists?(row.id)

  def deleted_player(steam_id, ago)
    Accounts::Player.create!(steam_id:).tap { it.update_columns(steam_id: nil, deleted_at: @now - ago) }
  end

  test "a ban in force is kept however old, and its reason still read at sign-in" do
    @banned.update_columns(updated_at: @now - 5.years)
    ban = action(:ban, 5.years, player: @banned, reason: "Insults in the name")

    assert_equal 0, purge
    assert kept?(ban)
    assert_equal "Insults in the name", Accounts::CurrentBanReason.call(@banned.steam_id)
  end

  test "a ban lifted a year and a second ago goes with its unban; the player's current ban stays" do
    lifted = action(:ban, 3.years, player: @banned)
    unban = action(:unban, 1.year + 1.second, player: @banned)
    current = action(:ban, 1.day, player: @banned, reason: "Insults in the name")

    assert_equal 2, purge
    assert_not kept?(lifted)
    assert_not kept?(unban)
    assert kept?(current)
    assert_equal "Insults in the name", Accounts::CurrentBanReason.call(@banned.steam_id)
  end

  test "a ban lifted a second short of a year ago is kept with its unban" do
    ban = action(:ban, 3.years)
    unban = action(:unban, 1.year - 1.second)

    assert_equal 0, purge
    assert kept?(ban)
    assert kept?(unban)
  end

  test "a ban ends at the first unban after it, by time then by row" do
    ban = action(:ban, 2.years)
    unban = Accounts::ModerationAction.create!(kind: :unban, player: @player, staff: @moderator, created_at: ban.created_at)
    action(:ban, 2.days)
    action(:unban, 1.day)

    assert_equal 2, purge
    assert_not kept?(ban)
    assert_not kept?(unban)
  end

  test "a ban lifted by hand, with no unban, ends at the player's last update" do
    ban = action(:ban, 3.years)
    @player.update_columns(updated_at: @now - 1.year + 1.second)

    assert_equal 0, purge
    assert kept?(ban)

    @player.update_columns(updated_at: @now - 1.year - 1.second)

    assert_equal 1, purge
    assert_not kept?(ban)
  end

  test "a dismissal made a year and a second ago is purged; a second short of a year, kept" do
    old = action(:dismissal, 1.year + 1.second)
    recent = action(:dismissal, 1.year - 1.second)

    assert_equal 1, purge
    assert_not kept?(old)
    assert kept?(recent)
  end

  test "the history of an account deleted a year and a second ago is purged whatever its age; a second short of a year, kept" do
    gone = deleted_player("76561197960420001", 1.year + 1.second)
    gone_rows = [ action(:ban, 2.years, player: gone), action(:unban, 1.year + 2.seconds, player: gone), action(:dismissal, 1.day, player: gone) ]
    recent = deleted_player("76561197960420002", 1.year - 1.second)
    recent_rows = [ action(:ban, 5.years, player: recent), action(:dismissal, 4.years, player: recent) ]

    assert_equal 3, purge
    assert gone_rows.none? { kept?(it) }
    assert recent_rows.all? { kept?(it) }
  end

  test "each call takes up to the limit of players, every expired row of each, so a ban never outlives its unban" do
    first = [ action(:ban, 3.years), action(:unban, 2.years), action(:dismissal, 2.years) ]
    second = [ action(:dismissal, 2.years, player: @banned) ]

    assert_equal 3, purge(limit: 1)
    assert first.none? { kept?(it) }
    assert second.all? { kept?(it) }
    assert_equal 1, purge(limit: 1)
    assert_equal 0, purge(limit: 1)
  end

  test "no event is published" do
    action(:dismissal, 2.years)

    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      assert_equal 1, purge
    end
  end
end
