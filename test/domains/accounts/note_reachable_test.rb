require "test_helper"

class Accounts::NoteReachableTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @now = Time.utc(2026, 11, 16, 15, 0)
  end

  test "the lease runs 45 seconds ahead, in one statement, publishing nothing and leaving updated_at" do
    updated_at = @player.updated_at
    events = Rails.configuration.event_store.read.count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/i) }

    result = nil
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { result = Accounts::NoteReachable.new.call(player_id: @player.id, at: @now) }

    assert_equal 1, result.value!
    assert_equal @now + 45.seconds, @player.reload.reachable_until
    assert_equal 1, queries.size, queries.inspect
    assert_match(/\AUPDATE "accounts_players"/, queries.sole)
    assert_equal updated_at, @player.updated_at
    assert_equal events, Rails.configuration.event_store.read.count
  end

  test "a removed or unknown player is left alone" do
    banned = accounts_players(:banned)

    assert_equal 0, Accounts::NoteReachable.new.call(player_id: banned.id, at: @now).value!
    assert_nil banned.reload.reachable_until
    assert_equal 0, Accounts::NoteReachable.new.call(player_id: 0, at: @now).value!
  end
end
