require "test_helper"

class Game::InvitationsWaitingTest < ActiveSupport::TestCase
  setup do
    @hugo = accounts_players(:player)
    @max = accounts_players(:moderator)
    @eve = accounts_players(:administrator)
  end

  def invite(from, to, status: "pending")
    Game::Invitation.create!(sender_id: from.id, recipient_id: to.id, status:)
  end

  test "a pending invitation counts for its recipient, never for its sender" do
    invite(@max, @hugo)
    invite(@eve, @hugo)

    assert_equal 2, Game::InvitationsWaiting.call(@hugo)
    assert_equal 0, Game::InvitationsWaiting.call(@max)
  end

  test "an ignored or accepted invitation waits for nothing" do
    invite(@max, @hugo, status: "ignored")
    invite(@eve, @hugo, status: "accepted")

    assert_equal 0, Game::InvitationsWaiting.call(@hugo)
  end

  test "an invitation from a banned or deleted sender no longer counts" do
    invite(@max, @hugo)
    invite(@eve, @hugo)
    @max.update_columns(banned_at: Time.current)
    Accounts::DeletePlayer.new.call(player: @eve).value!

    assert_equal 0, Game::InvitationsWaiting.call(@hugo)
  end

  test "a visitor has nothing waiting, without a query" do
    assert_no_queries { assert_equal 0, Game::InvitationsWaiting.call(nil) }
  end
end
