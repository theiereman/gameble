require "test_helper"

class ProfileRelationTest < ActiveSupport::TestCase
  setup do
    @owner = accounts_players(:player)
    @viewer = accounts_players(:moderator)
  end

  test "a visitor, the owner and a stranger" do
    assert_equal :visitor, Game::ProfileRelation.call(nil, @owner)
    assert_equal :self, Game::ProfileRelation.call(@owner, @owner)
    assert_equal :none, Game::ProfileRelation.call(@viewer, @owner)
  end

  test "an invitation sent, an invitation received" do
    Game::Invitation.create!(sender_id: @viewer.id, recipient_id: @owner.id)
    assert_equal :invited, Game::ProfileRelation.call(@viewer, @owner)
    assert_equal :invited_by, Game::ProfileRelation.call(@owner, @viewer)
  end

  test "an invitation received then ignored is no longer there to accept" do
    Game::Invitation.create!(sender_id: @owner.id, recipient_id: @viewer.id, status: "ignored")
    assert_equal :none, Game::ProfileRelation.call(@viewer, @owner)
    assert_equal :invited, Game::ProfileRelation.call(@owner, @viewer)
  end

  test "friends outrank a pending invitation" do
    Game::Invitation.create!(sender_id: @owner.id, recipient_id: @viewer.id)
    Game::Friendship.create!(low_player_id: [ @owner.id, @viewer.id ].min, high_player_id: [ @owner.id, @viewer.id ].max)

    assert_equal :friends, Game::ProfileRelation.call(@viewer, @owner)
  end
end
