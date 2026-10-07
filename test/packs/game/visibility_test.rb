require "test_helper"

# Game::Visibility (AD-13, AD-14): the one visibility question.
class Game::VisibilityTest < ActiveSupport::TestCase
  setup do
    @owner = accounts_players(:player)
    @stranger = accounts_players(:moderator)
  end

  def visible?(viewer, owner = @owner) = Game::Visibility.visible?(viewer, owner)

  def befriend(one, other)
    Game::Friendship.create!(low_player_id: [ one.id, other.id ].min, high_player_id: [ one.id, other.id ].max)
  end

  test "a public owner is seen by a visitor, a stranger and themselves" do
    assert visible?(nil)
    assert visible?(@stranger)
    assert visible?(@owner)
  end

  test "a private owner is seen by themselves only" do
    @owner.visibility_private!

    assert visible?(@owner)
    assert_not visible?(nil)
    assert_not visible?(@stranger)
  end

  test "a friends-only owner is seen by themselves and their friends only" do
    @owner.visibility_friends_only!
    friend = accounts_players(:administrator)
    befriend(@owner, friend)

    assert visible?(@owner)
    assert visible?(friend)
    assert_not visible?(nil)
    assert_not visible?(@stranger)
  end

  test "a private owner is hidden from their friends too" do
    @owner.visibility_private!
    friend = accounts_players(:administrator)
    befriend(@owner, friend)

    assert_not visible?(friend)
  end

  test "a banned friends-only owner is hidden from their friends" do
    banned = accounts_players(:banned)
    banned.visibility_friends_only!
    befriend(banned, @stranger)

    assert_not visible?(@stranger, banned)
  end

  test "a banned owner is seen by no one, themselves included, whatever their visibility" do
    banned = accounts_players(:banned)

    assert_not visible?(nil, banned)
    assert_not visible?(banned, banned)
    assert_not visible?(@stranger, banned)
  end

  test "a deleted owner is seen by no one, themselves included" do
    Accounts::DeletePlayer.new.call(player: @owner).value!

    assert_not visible?(nil)
    assert_not visible?(@stranger)
    assert_not visible?(@owner)
  end

  test "no owner is seen by no one" do
    assert_not visible?(nil, nil)
    assert_not visible?(@owner, nil)
  end
end
