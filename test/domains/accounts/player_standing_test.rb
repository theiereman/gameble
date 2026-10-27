require "test_helper"

class Accounts::PlayerStandingTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @banned = accounts_players(:banned)
    @deleted = accounts_players(:moderator)
    @deleted.update_columns(steam_id: nil, deleted_at: Time.current)
  end

  test "a banned or deleted player is removed, the others are in good standing" do
    assert_not @player.removed?
    assert @banned.removed?
    assert @deleted.removed?

    ids = [ @player, @banned, @deleted ].map(&:id)
    assert_equal [ @player.id ], Accounts::Player.in_good_standing.where(id: ids).pluck(:id)
    assert_equal [ @banned.id, @deleted.id ].sort, Accounts::Player.removed.where(id: ids).pluck(:id).sort
  end

  test "roles rank player, moderator, administrator; no role outranks itself" do
    player, moderator, administrator = %w[player moderator administrator].map { Accounts::Player.new(role: it) }

    assert moderator.outranks?(player)
    assert administrator.outranks?(moderator)
    assert administrator.outranks?(player)
    [ player, moderator, administrator ].each { |role| assert_not role.outranks?(Accounts::Player.new(role: role.role)), role.role }
    assert_not moderator.outranks?(administrator)
    assert_not player.outranks?(moderator)
  end
end
