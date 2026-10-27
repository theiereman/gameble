require "test_helper"
require Rails.root.join("db/migrate/20261009130001_copy_moderation_events_to_accounts_moderation_actions").to_s

# The data migration that copies the bans, lifted bans and dismissals the
# event store recorded before the moderation history existed.
class Accounts::ModerationHistoryMigrationTest < ActiveSupport::TestCase
  setup do
    @moderator = accounts_players(:moderator)
    @administrator = accounts_players(:administrator)
    @target = accounts_players(:player)
    @banned = accounts_players(:banned)
  end

  def migrate
    ActiveRecord::Migration.suppress_messages { CopyModerationEventsToAccountsModerationActions.new.migrate(:up) }
  end

  def publish(type, player_id, staff_id, at)
    travel_to(at) do
      Rails.configuration.event_store.publish(type.new(data: { player_id:, staff_id: }), stream_name: "Accounts::Player$#{player_id}")
    end
  end

  def rows = Accounts::ModerationAction.order(:created_at).map { [ it.kind, it.player_id, it.staff_id, it.reason, it.created_at ] }

  test "each moderation event becomes a line of the history, with its time and no reason; other events are left out" do
    publish(Accounts::PlayerBanned, @target.id, @moderator.id, Time.utc(2026, 10, 7, 9))
    publish(Accounts::PlayerUnbanned, @target.id, @administrator.id, Time.utc(2026, 10, 7, 10))
    publish(Accounts::ReportsDismissed, @banned.id, @moderator.id, Time.utc(2026, 10, 8, 11))
    travel_to(Time.utc(2026, 10, 8, 12)) do
      Rails.configuration.event_store.publish(Accounts::RoleChanged.new(data: { player_id: @target.id, role: "moderator" }),
        stream_name: "Accounts::Player$#{@target.id}")
    end

    migrate

    assert_equal [
      [ "ban", @target.id, @moderator.id, nil, Time.utc(2026, 10, 7, 9) ],
      [ "unban", @target.id, @administrator.id, nil, Time.utc(2026, 10, 7, 10) ],
      [ "dismissal", @banned.id, @moderator.id, nil, Time.utc(2026, 10, 8, 11) ]
    ], rows
  end

  def name_missing(type, key)
    missing = Accounts::Player.maximum(:id) + 1_000
    ActiveRecord::Base.connection.exec_update(ActiveRecord::Base.sanitize_sql_array([
      "UPDATE event_store_events SET data = jsonb_set(data, ARRAY[?], to_jsonb(?::bigint)) WHERE event_type = ?", key, missing, type.name
    ]))
  end

  test "an event naming a player whose record is gone is left out" do
    publish(Accounts::PlayerBanned, @target.id, @moderator.id, Time.utc(2026, 10, 7, 9))
    publish(Accounts::ReportsDismissed, @banned.id, @moderator.id, Time.utc(2026, 10, 7, 10))
    name_missing(Accounts::PlayerBanned, "player_id")
    name_missing(Accounts::ReportsDismissed, "staff_id")

    migrate

    assert_empty rows
  end
end
