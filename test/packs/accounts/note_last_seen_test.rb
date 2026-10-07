require "test_helper"

# Accounts::NoteLastSeen and its job (CAP-21, AD-24, story 5.3): a player's
# last-seen time moves forward at most once a minute, never past now, in
# one UPDATE that publishes nothing.
class Accounts::NoteLastSeenTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @player = accounts_players(:player)
    @now = Time.utc(2026, 10, 7, 15, 0)
  end

  def note(at, player: @player) = Accounts::NoteLastSeen.new.call(player_id: player.id, at:)
  def last_seen = @player.reload.last_seen_at

  test "a first sighting writes the time in one statement, publishing nothing and leaving updated_at" do
    travel_to(@now) do
      updated_at = @player.updated_at
      events = Rails.configuration.event_store.read.count
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/i) }

      result = nil
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { result = note(@now - 5.seconds) }

      assert_equal true, result.value!
      assert_equal @now - 5.seconds, last_seen
      assert_equal 1, queries.size, queries.inspect
      assert_match(/\AUPDATE "accounts_players"/, queries.sole)
      assert_equal updated_at, @player.reload.updated_at
      assert_equal events, Rails.configuration.event_store.read.count
    end
  end

  test "within a minute of the stored time nothing is written; a minute later it moves" do
    travel_to(@now) do
      @player.update_columns(last_seen_at: @now - 30.seconds)

      assert_equal false, note(@now).value!
      assert_equal @now - 30.seconds, last_seen

      @player.update_columns(last_seen_at: @now - 1.minute)
      assert_equal true, note(@now).value!
      assert_equal @now, last_seen
    end
  end

  test "an older time never moves it back" do
    travel_to(@now) do
      @player.update_columns(last_seen_at: @now)

      assert_equal false, note(@now - 1.hour).value!
      assert_equal @now, last_seen
    end
  end

  test "a time in the future is stored as now" do
    travel_to(@now) do
      assert note(@now + 1.day).success?
      assert_equal @now, last_seen
    end
  end

  test "a banned or unknown player is left alone; a time is required" do
    banned = accounts_players(:banned)

    assert_equal false, note(Time.current, player: banned).value!
    assert_nil banned.reload.last_seen_at
    assert_equal false, Accounts::NoteLastSeen.new.call(player_id: 0, at: Time.current).value!
    assert_equal :invalid_time, note("now").failure
  end

  test "the job writes the time the request saw the player" do
    travel_to(@now) do
      Accounts::NoteLastSeenJob.perform_later(@player.id, @now - 2.seconds)
      perform_enqueued_jobs

      assert_equal @now - 2.seconds, last_seen
    end
  end
end
