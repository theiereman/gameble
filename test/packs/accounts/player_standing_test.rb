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
end
