require "test_helper"
require_relative "../../support/rake_tasks"

class Accounts::SetRoleTest < ActiveSupport::TestCase
  include RakeTasks

  setup do
    @player = accounts_players(:player)
    rake_task("accounts:set_role")
  end

  teardown do
    Rake::Task["accounts:set_role"].reenable
  end

  def set_role(role, steam_id: @player.steam_id) = Accounts::SetRole.new.call(steam_id:, role:)

  def role_events = Rails.configuration.event_store.read.of_type(Accounts::RoleChanged).to_a

  test "it stores the role and publishes RoleChanged" do
    assert_equal @player, set_role("moderator").value!
    assert_predicate @player.reload, :moderator?

    assert set_role(:administrator).success?
    assert_predicate @player.reload, :administrator?

    published = Rails.configuration.event_store.read.stream("Accounts::Player$#{@player.id}").of_type(Accounts::RoleChanged).to_a
    assert_equal [ { player_id: @player.id, role: "moderator" }, { player_id: @player.id, role: "administrator" } ], published.map(&:data)
  end

  test "the role a player already holds changes nothing" do
    assert set_role("player").success?
    assert_empty role_events
  end

  [ nil, "", "admin", "Moderator", 1 ].each do |role|
    test "the role #{role.inspect} is refused" do
      assert_equal Dry::Monads::Failure(:invalid_role), set_role(role)
      assert_predicate @player.reload, :player?
      assert_empty role_events
    end
  end

  test "an unknown Steam id or a deleted account is not found" do
    deleted = Accounts::Player.create!(steam_id: "76561197960340001")
    steam_id = deleted.steam_id
    Accounts::DeletePlayer.new.call(player: deleted).value!

    [ "76561197960340002", steam_id, "", nil ].each do |unknown|
      assert_equal Dry::Monads::Failure(:player_not_found), set_role("moderator", steam_id: unknown)
    end
    assert_empty role_events
  end

  test "the task sets the role and says so" do
    assert_output(/#{@player.steam_id} is now moderator/) { rake_task("accounts:set_role").invoke(@player.steam_id, "moderator") }

    assert_predicate @player.reload, :moderator?
  end

  test "the task aborts with the reason" do
    _, err = capture_io { assert_raises(SystemExit) { rake_task("accounts:set_role").invoke("76561197960340002", "moderator") } }
    assert_match(/accounts:set_role: That profile could not be found\./, err)

    Rake::Task["accounts:set_role"].reenable
    _, err = capture_io { assert_raises(SystemExit) { rake_task("accounts:set_role").invoke(@player.steam_id, "admin") } }
    assert_match(/accounts:set_role: That role does not exist/, err)
    assert_predicate @player.reload, :player?
  end
end
