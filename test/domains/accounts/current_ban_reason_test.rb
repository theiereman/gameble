require "test_helper"

class Accounts::CurrentBanReasonTest < ActiveSupport::TestCase
  setup do
    @moderator = accounts_players(:moderator)
    @banned = accounts_players(:banned)
  end

  def action(kind, at, player: @banned, reason: nil)
    Accounts::ModerationAction.create!(kind:, player:, staff: @moderator, reason:, created_at: at)
  end

  def reason_for(player = @banned)
    Accounts::CurrentBanReason.call(player.steam_id)
  end

  test "the reason of the ban that holds" do
    action(:ban, 1.day.ago, reason: "Insults in the name")

    assert_equal "Insults in the name", reason_for
  end

  test "a ban recorded without a reason gives none" do
    action(:ban, 1.day.ago)

    assert_nil reason_for
  end

  test "a banned player with no ban recorded gives none" do
    assert_nil reason_for
  end

  test "banned again, the reason of the latest ban" do
    action(:ban, 3.days.ago, reason: "Spam")
    action(:unban, 2.days.ago)
    action(:ban, 1.day.ago, reason: "Insults in the name")

    assert_equal "Insults in the name", reason_for
  end

  test "the later row wins at the same time" do
    first = action(:ban, 1.day.ago, reason: "Spam")
    action(:ban, first.created_at, reason: "Insults in the name")

    assert_equal "Insults in the name", reason_for
  end

  test "banned while the latest recorded action is an unban gives none" do
    action(:ban, 2.days.ago, reason: "Spam")
    action(:unban, 1.day.ago)

    assert_nil reason_for
  end

  test "a dismissal after the ban does not hide its reason" do
    action(:ban, 2.days.ago, reason: "Spam")
    action(:dismissal, 1.day.ago)

    assert_equal "Spam", reason_for
  end

  test "a player who is not banned gives none, even with a ban recorded" do
    player = accounts_players(:player)
    action(:ban, 1.day.ago, player:, reason: "Spam")

    assert_nil reason_for(player)
  end

  test "an unknown or non-String Steam id gives none" do
    assert_nil Accounts::CurrentBanReason.call("76561197960299999")
    assert_nil Accounts::CurrentBanReason.call(nil)
    assert_nil Accounts::CurrentBanReason.call(@banned.steam_id.to_i)
    assert_nil Accounts::CurrentBanReason.call([ @banned.steam_id ])
  end
end
