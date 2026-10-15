require "test_helper"
require Rails.root.join("db/migrate/20261015120000_welcome_every_existing_player").to_s

class Accounts::WelcomeEveryExistingPlayerMigrationTest < ActiveSupport::TestCase
  def migrate
    ActiveRecord::Migration.suppress_messages { WelcomeEveryExistingPlayer.new.migrate(:up) }
  end

  test "every account that exists gets the welcome pending, a deleted one excepted" do
    player = accounts_players(:player)
    deleted = Accounts::Player.create!(steam_id: nil, deleted_at: Time.current)

    migrate

    assert_predicate player.reload, :welcome_pending
    assert_not deleted.reload.welcome_pending
  end
end
