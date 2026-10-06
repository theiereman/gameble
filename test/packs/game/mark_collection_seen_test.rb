require "test_helper"
require_relative "../../support/game_packs"

# Game::MarkCollectionSeen (AD-26, story 10.1): the collection's watermark
# only moves forward, never past now, in one upsert that publishes nothing.
class Game::MarkCollectionSeenTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @state = Game::PlayerState.find_by!(player_id: @player.id)
  end

  def mark(up_to, player: @player) = Game::MarkCollectionSeen.new.call(player:, up_to:)
  def watermark = @state.reload.collection_seen_up_to

  # A time an hour ago, at the microsecond `usec`.
  def ago(usec, hours: 1) = (Time.current - hours.hours).change(usec:)

  test "a first mark sets the watermark, to the microsecond, in one statement, publishing nothing" do
    up_to = ago(123_456)

    result = nil
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|SAVEPOINT|RELEASE)/i) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { result = mark(up_to) }

    assert result.success?
    assert_equal up_to, result.value!
    assert_equal up_to, watermark
    assert_equal 123456, watermark.usec
    assert_equal 1, queries.size, queries.inspect
    assert_match(/INSERT INTO "game_player_states".*ON CONFLICT \("player_id"\) DO UPDATE SET collection_seen_up_to = GREATEST/, queries.sole)
    assert_empty game_events(@player)
  end

  test "a later time moves it forward; an earlier one leaves it" do
    seen = ago(500_000)
    @state.update_columns(collection_seen_up_to: seen)

    assert mark(seen.change(usec: 500_001)).success?
    assert_equal seen.change(usec: 500_001), watermark

    result = mark(ago(0, hours: 2))
    assert result.success?
    assert_equal seen.change(usec: 500_001), result.value!
    assert_equal seen.change(usec: 500_001), watermark
  end

  test "a time in the future is stored as now" do
    freeze_time do
      assert mark(1.day.from_now).success?

      assert_equal Time.current, watermark
    end
  end

  test "a player without a state row gets one with the time" do
    @state.delete
    up_to = 1.minute.ago

    assert_difference -> { Game::PlayerState.count }, 1 do
      assert mark(up_to).success?
    end
    assert_in_delta up_to, Game::PlayerState.find_by!(player_id: @player.id).collection_seen_up_to, 0.000001
  end

  test "only the player's row changes" do
    other = Game::PlayerState.find_by!(player_id: accounts_players(:moderator).id)

    assert_no_changes -> { other.reload.attributes } do
      mark(1.minute.ago)
    end
  end

  test "anything but a time fails with invalid_time and writes nothing" do
    [ nil, "2026-10-06T10:00:00Z", 1_700_000_000, Date.current ].each do |up_to|
      assert_no_changes -> { @state.reload.attributes } do
        assert_equal :invalid_time, mark(up_to).failure
      end
    end
  end

  test "a visitor, an unsaved or a banned player fails with player_required" do
    [ nil, Accounts::Player.new(steam_id: "76561197960287888"), accounts_players(:banned) ].each do |player|
      assert_equal :player_required, mark(1.minute.ago, player:).failure
    end
    assert_nil watermark
  end

  test "its failures have messages in both locales" do
    %w[en fr].each do |locale|
      I18n.with_locale(locale) { assert_not_includes Game::MarkCollectionSeen.failure_message(:invalid_time), "translation missing" }
    end
  end
end
