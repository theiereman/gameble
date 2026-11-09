require "test_helper"
require_relative "../../support/game_packs"

class Game::RecordRevealTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @older = create_pack(@player, opened_at: 2.minutes.ago)
    @latest = create_pack(@player, kind: :bonus, opened_at: 1.minute.ago)
  end

  def reveal(mode, pack: @latest, player: @player, token: pack.token) = Game::RecordReveal.new.call(player:, token:, mode:)

  def events = game_events(@player, Game::PackRevealed)

  def assert_nothing_written
    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      assert_no_changes -> { Game::Pack.where(player_id: @player.id).order(:id).pluck(:reveal_mode) } do
        yield
      end
    end
  end

  test "the latest opened pack stores the mode and publishes it once" do
    result = reveal("all")

    assert result.success?
    assert_equal "all", @latest.reload.reveal_mode
    assert_equal [ { player_id: @player.id, pack_id: @latest.id, mode: "all" } ], events.map(&:data)
  end

  test "a repeat on a revealed pack succeeds and changes nothing, whatever its mode" do
    reveal("one_by_one")

    assert_nothing_written do
      assert reveal("all").success?
      assert reveal("one_by_one").success?
    end
    assert_equal "one_by_one", @latest.reload.reveal_mode
    assert_equal 1, events.size
  end

  test "an opened pack that is not the latest is refused" do
    assert_nothing_written { assert_equal :not_latest_pack, reveal("all", pack: @older).failure }
  end

  test "the latest pack is the one opened last, the later id breaking a tie" do
    @older.update!(opened_at: @latest.reload.opened_at)

    assert_equal :not_latest_pack, reveal("all", pack: @older).failure
    assert reveal("all", pack: @latest).success?
  end

  test "an unopened pack, another player's pack or an unknown token is not found" do
    unopened = create_pack(@player)
    stranger = create_pack(accounts_players(:moderator), opened_at: Time.current)

    assert_nothing_written do
      assert_equal :pack_not_found, reveal("all", pack: unopened).failure
      assert_equal :pack_not_found, reveal("all", token: stranger.token).failure
      assert_equal :pack_not_found, reveal("all", token: "x" * 24).failure
      assert_equal :pack_not_found, reveal("all", token: nil).failure
    end
    assert_nil stranger.reload.reveal_mode
  end

  test "a missing, unknown or non-string mode is refused" do
    assert_nothing_written do
      [ nil, "", "fast", "ALL", :all, [ "all" ], { "mode" => "all" }, 1 ].each do |mode|
        assert_equal :invalid_reveal_mode, reveal(mode).failure
      end
    end
  end

  test "a banned or missing player is refused" do
    assert_nothing_written { assert_equal :player_required, reveal("all", player: nil).failure }

    @player.update!(banned_at: Time.current)
    assert_nothing_written { assert_equal :player_required, reveal("all").failure }
  end

  test "the pack refuses a mode outside the known ones" do
    @latest.reveal_mode = "fast"

    assert_not @latest.valid?
    assert_raises(ActiveRecord::StatementInvalid) { @latest.update_column(:reveal_mode, "fast") }
  end

  test "each refusal has a message in each locale" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        %i[invalid_reveal_mode pack_not_found not_latest_pack].each do |code|
          assert_not_includes Game::RecordReveal.failure_message(code), "Translation missing"
        end
      end
    end
  end
end

class Game::RecordRevealConcurrencyTest < ActiveSupport::TestCase
  include GamePacks

  self.use_transactional_tests = false

  setup do
    @player = accounts_players(:player)
    @pack = create_pack(@player, opened_at: Time.current)
  end

  teardown do
    Game::Pack.where(player_id: @player.id).delete_all
    Game::Fortune.where(player_id: @player.id).delete_all
    stream = Game::Operation.stream_name(@player.id)
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
  end

  def reveal_together(modes)
    gate = Queue.new
    threads = modes.map do |mode|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          Game::RecordReveal.new.call(player: Accounts::Player.find(@player.id), token: @pack.token, mode:)
        end
      end
    end
    modes.size.times { gate << :go }
    threads.map { |thread| thread.join(20) ? thread.value : flunk("a thread is stuck: deadlock") }
  end

  test "two reveals of the same pack at once: both succeed, one mode is stored and published once" do
    results = reveal_together(%w[all one_by_one])

    assert results.all?(&:success?)
    events = game_events(@player, Game::PackRevealed)
    assert_equal 1, events.size
    assert_equal events.first.data[:mode], @pack.reload.reveal_mode
  end
end
