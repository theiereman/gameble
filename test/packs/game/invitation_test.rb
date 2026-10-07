require "test_helper"

class Game::InvitationTest < ActiveSupport::TestCase
  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
  end

  def send_by_code(from, to_code)
    Game::SendInvitation.new.call(player: from, code: to_code)
  end

  def friends?(one, other)
    low, high = [ one.id, other.id ].minmax
    Game::Friendship.exists?(low_player_id: low, high_player_id: high)
  end

  test "a valid code sends a pending invitation and publishes its event" do
    invitation = send_by_code(@alice, "8F2D-K9XM").value!

    assert_equal [ "pending", @alice.id, @bob.id ], [ invitation.status, invitation.sender_id, invitation.recipient_id ]
    assert_match(/\A[1-9A-HJ-NP-Za-km-z]{24}\z/, invitation.token)
    assert_not friends?(@alice, @bob)
    events = Rails.configuration.event_store.read.of_type([ Game::InvitationSent ]).to_a
    assert_equal invitation.id, events.last.data[:invitation_id]
  end

  test "a code is trimmed and upcased" do
    assert send_by_code(@alice, " 8f2d-k9xm ").success?
  end

  test "a wrong format is refused" do
    [ "", "abc", "8F2DK9XM", "8F2D-K9X0", nil ].each do |code|
      assert_equal :invalid_format, send_by_code(@alice, code).failure, code.inspect
    end
    assert_equal 0, Game::Invitation.count
  end

  test "the player's own code is refused" do
    assert_equal :own_code, send_by_code(@alice, "7K2Q-F3NX").failure
  end

  test "a code nobody holds, or a banned owner's, is unknown" do
    assert_equal :unknown_code, send_by_code(@alice, "2222-3333").failure
    assert_equal :unknown_code, send_by_code(@alice, "9ABC-D4EF").failure
  end

  test "a repeated invitation is refused" do
    send_by_code(@alice, "8F2D-K9XM").value!

    assert_equal :already_sent, send_by_code(@alice, "8F2D-K9XM").failure
    assert_equal 1, Game::Invitation.count
  end

  test "friends cannot invite each other" do
    Game::Friendship.create!(low_player_id: [ @alice.id, @bob.id ].min, high_player_id: [ @alice.id, @bob.id ].max)

    assert_equal :already_friends, send_by_code(@alice, "8F2D-K9XM").failure
  end

  test "the invite link sends the same invitation, by the owner's token" do
    invitation = Game::SendInvitation.new.call(player: @alice, recipient_token: @bob.token).value!

    assert_equal @bob.id, invitation.recipient_id
    assert_equal :own_link, Game::SendInvitation.new.call(player: @alice, recipient_token: @alice.token).failure
    assert_equal :unknown_player, Game::SendInvitation.new.call(player: @alice, recipient_token: "nope").failure
    assert_equal :unknown_player, Game::SendInvitation.new.call(player: @alice, recipient_token: accounts_players(:banned).token).failure
  end

  test "a visitor cannot send" do
    assert_equal :player_required, Game::SendInvitation.new.call(player: nil, code: "8F2D-K9XM").failure
  end

  test "accepting makes the friendship in the same operation" do
    invitation = send_by_code(@alice, "8F2D-K9XM").value!

    accepted = Game::AcceptInvitation.new.call(player: @bob, token: invitation.token).value!

    assert_equal "accepted", accepted.status
    assert friends?(@alice, @bob)
    assert_equal [ @bob ], Game::FriendsOf.call(@alice)
    assert_equal [ @alice ], Game::FriendsOf.call(@bob)
  end

  test "only the recipient can answer, once" do
    invitation = send_by_code(@alice, "8F2D-K9XM").value!

    assert_equal :not_found, Game::AcceptInvitation.new.call(player: @alice, token: invitation.token).failure
    assert_equal :not_found, Game::IgnoreInvitation.new.call(player: accounts_players(:administrator), token: invitation.token).failure
    assert_equal :not_found, Game::AcceptInvitation.new.call(player: @bob, token: "nope").failure
    Game::AcceptInvitation.new.call(player: @bob, token: invitation.token).value!
    assert_equal :not_found, Game::AcceptInvitation.new.call(player: @bob, token: invitation.token).failure
  end

  test "a failed friendship rolls the acceptance back" do
    invitation = send_by_code(@alice, "8F2D-K9XM").value!
    original = Game::Friendship.method(:insert)
    Game::Friendship.define_singleton_method(:insert) { |*, **| raise ActiveRecord::StatementInvalid, "boom" }
    begin
      assert_raises(ActiveRecord::StatementInvalid) { Game::AcceptInvitation.new.call(player: @bob, token: invitation.token) }
    ensure
      Game::Friendship.define_singleton_method(:insert, original)
    end

    assert_equal "pending", invitation.reload.status
  end

  test "ignoring creates nothing" do
    invitation = send_by_code(@alice, "8F2D-K9XM").value!

    assert_equal "ignored", Game::IgnoreInvitation.new.call(player: @bob, token: invitation.token).value!.status
    assert_not friends?(@alice, @bob)
    assert_empty Game::InvitationsOf.call(@bob).received
    assert_equal :not_found, Game::AcceptInvitation.new.call(player: @bob, token: invitation.token).failure
  end

  test "inviting someone who invited you accepts their invitation" do
    send_by_code(@bob, "7K2Q-F3NX").value!

    result = send_by_code(@alice, "8F2D-K9XM").value!

    assert_equal "accepted", result.status
    assert friends?(@alice, @bob)
    assert_equal 1, Game::Invitation.count
  end

  test "the query lists received and sent invitations, banned players left out" do
    send_by_code(@alice, "8F2D-K9XM").value!
    send_by_code(accounts_players(:administrator), "7K2Q-F3NX").value!

    mine = Game::InvitationsOf.call(@alice)
    assert_equal [ "administrator" ].map { accounts_players(:administrator) }, mine.received.map(&:player)
    assert_equal [ "8F2D-K9XM" ], mine.sent.map(&:code)
    assert_equal [ @bob ], mine.sent.map(&:player)
    assert_equal [], Game::InvitationsOf.call(nil).received
  end
end
