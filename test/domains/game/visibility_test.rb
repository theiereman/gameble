require "test_helper"

class Game::VisibilityTest < ActiveSupport::TestCase
  setup do
    @owner = accounts_players(:player)
    @stranger = Accounts::Player.create!(steam_id: "76561197960390001")
    @friend = Accounts::Player.create!(steam_id: "76561197960390002")
    @moderator = accounts_players(:moderator)
    @administrator = accounts_players(:administrator)
  end

  def visible?(viewer, owner = @owner, **options) = Game::Visibility.visible?(viewer, owner, **options)

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
    befriend(@owner, @friend)

    assert visible?(@owner)
    assert visible?(@friend)
    assert_not visible?(nil)
    assert_not visible?(@stranger)
  end

  test "a private owner is hidden from their friends too" do
    @owner.visibility_private!
    befriend(@owner, @friend)

    assert_not visible?(@friend)
  end

  test "a banned friends-only owner is hidden from their friends" do
    banned = accounts_players(:banned)
    banned.visibility_friends_only!
    befriend(banned, @friend)

    assert_not visible?(@friend, banned)
  end

  test "a banned owner is seen by no player, themselves included, whatever their visibility" do
    banned = accounts_players(:banned)

    assert_not visible?(nil, banned)
    assert_not visible?(banned, banned)
    assert_not visible?(@stranger, banned)
  end

  test "a deleted owner is seen by no one, themselves and staff included" do
    Accounts::DeletePlayer.new.call(player: @owner).value!

    [ nil, @stranger, @owner, @moderator, @administrator ].each { |viewer| assert_not visible?(viewer), viewer&.role }
  end

  test "no owner is seen by no one" do
    assert_not visible?(nil, nil)
    assert_not visible?(@owner, nil)
    assert_not visible?(@moderator, nil)
  end

  test "staff see a private, a friends-only and a banned owner" do
    banned = accounts_players(:banned).tap { it.visibility_private! }

    [ @moderator, @administrator ].each do |staff|
      assert visible?(staff, banned), staff.role
      @owner.visibility_private!
      assert visible?(staff), staff.role
      @owner.visibility_friends_only!
      assert visible?(staff), staff.role
    end
  end

  test "a surface that opts out shows staff what a player would see" do
    banned = accounts_players(:banned)
    @owner.visibility_private!

    assert_not visible?(@moderator, staff_sees_all: false)
    assert_not visible?(@moderator, banned, staff_sees_all: false)
    @owner.visibility_friends_only!
    befriend(@owner, @moderator)
    assert visible?(@moderator, staff_sees_all: false)
    @owner.visibility_public!
    assert visible?(@administrator, staff_sees_all: false)
  end

  test "a banned or deleted member of staff is no staff" do
    @owner.visibility_private!
    banned_moderator = @moderator.tap { it.update!(banned_at: Time.current) }
    deleted_administrator = Accounts::Player.create!(steam_id: "76561197960390003", role: :administrator)
    Accounts::DeletePlayer.new.call(player: deleted_administrator).value!

    assert_not visible?(banned_moderator)
    assert_not visible?(deleted_administrator.reload)
  end

  test "a public or friends-only player is open to friends, a private one is not" do
    assert Game::Visibility.open_to_friends?(@owner)
    @owner.visibility_friends_only!
    assert Game::Visibility.open_to_friends?(@owner)
    @owner.visibility_private!
    assert_not Game::Visibility.open_to_friends?(@owner)
  end

  test "a banned, deleted or missing player is open to no one" do
    Accounts::DeletePlayer.new.call(player: @friend).value!

    assert_not Game::Visibility.open_to_friends?(accounts_players(:banned))
    assert_not Game::Visibility.open_to_friends?(@friend.reload)
    assert_not Game::Visibility.open_to_friends?(nil)
  end
end
