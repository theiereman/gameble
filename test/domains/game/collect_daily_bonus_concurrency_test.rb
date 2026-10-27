require "test_helper"
require_relative "../../support/game_packs"

# Game::CollectDailyBonus under concurrency: the bank lock
# serialises two collections by the same player. Each thread has its own
# connection, so the test commits for real and cleans up after itself.
class Game::CollectDailyBonusConcurrencyTest < ActiveSupport::TestCase
  include GamePacks

  self.use_transactional_tests = false

  setup do
    @player = accounts_players(:player)
  end

  teardown do
    Game::DailyBonusClaim.where(player_id: @player.id).delete_all
    Game::Pack.where(player_id: @player.id).delete_all
    stream = Game::Operation.stream_name(@player.id)
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
  end

  test "two collections at once: one succeeds, the other is refused; one claim, one bonus pack" do
    # Nine available packs: one short of a full reserve, so the bonus is
    # refused for being taken, not for the reserve.
    9.times { |index| create_pack(@player, available_at: (index + 1).minutes.ago) }
    gate = Queue.new
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          Game::CollectDailyBonus.new.call(player: Accounts::Player.find(@player.id))
        end
      end
    end
    2.times { gate << :go }
    results = threads.map(&:value)

    assert_equal 1, results.count(&:success?)
    assert_equal [ :already_collected ], results.select(&:failure?).map(&:failure)
    assert_equal 1, Game::DailyBonusClaim.where(player_id: @player.id).count
    assert_equal 1, Game::Pack.where(player_id: @player.id).bonus.count
  end
end
