require "test_helper"

class Accounts::ModerationHistoryTest < ActiveSupport::TestCase
  setup do
    @moderator = accounts_players(:moderator)
    @target = accounts_players(:player)
    @banned = accounts_players(:banned)
  end

  def action(kind, player, at, reason: nil)
    Accounts::ModerationAction.create!(kind:, player:, staff: @moderator, reason:, created_at: at)
  end

  test "the latest action comes first, the later row first at the same time" do
    oldest = action(:ban, @target, 3.days.ago, reason: "Spam")
    tied_first = action(:unban, @target, 1.day.ago)
    tied_second = action(:dismissal, @banned, tied_first.created_at)
    latest = action(:ban, @banned, 1.hour.ago)

    assert_equal [ latest, tied_second, tied_first, oldest ], Accounts::ModerationHistory.call.to_a
  end

  test "given a player, only that player's actions" do
    first = action(:ban, @target, 2.days.ago, reason: "Spam")
    action(:dismissal, @banned, 1.day.ago)
    second = action(:unban, @target, 1.hour.ago)

    assert_equal [ second, first ], Accounts::ModerationHistory.call(@target).to_a
    assert_empty Accounts::ModerationHistory.call(@moderator)
  end

  test "the actions naming a deleted account stay, with its anonymised record" do
    deleted = Accounts::Player.create!(steam_id: "76561197960395001", persona_name: "Ghost")
    kept = action(:ban, deleted, 1.day.ago, reason: "Spam")
    Accounts::DeletePlayer.new.call(player: deleted).value!

    assert_equal [ kept ], Accounts::ModerationHistory.call.to_a
    assert_predicate Accounts::ModerationHistory.call.first.player, :deleted?
  end
end
