require "test_helper"

class Game::InvitationAwaitingTest < ActiveSupport::TestCase
  setup do
    @sender = accounts_players(:player)
    @recipient = accounts_players(:moderator)
  end

  def invite(status:, from: @sender, to: @recipient)
    Game::Invitation.create!(sender_id: from.id, recipient_id: to.id, status:)
  end

  test "a pending invitation from the sender awaits" do
    invite(status: "pending")

    assert Game::InvitationAwaiting.call(@sender, @recipient)
  end

  test "an ignored invitation still awaits, as the sender never learns it was ignored" do
    invite(status: "ignored")

    assert Game::InvitationAwaiting.call(@sender, @recipient)
  end

  test "an accepted invitation, none at all or one in the other direction does not" do
    assert_not Game::InvitationAwaiting.call(@sender, @recipient)

    invite(status: "pending", from: @recipient, to: @sender)
    assert_not Game::InvitationAwaiting.call(@sender, @recipient)

    invite(status: "accepted")
    assert_not Game::InvitationAwaiting.call(@sender, @recipient)
  end

  test "a visitor or a missing recipient awaits nothing, without a query" do
    assert_no_queries do
      assert_not Game::InvitationAwaiting.call(nil, @recipient)
      assert_not Game::InvitationAwaiting.call(@sender, nil)
    end
  end
end
