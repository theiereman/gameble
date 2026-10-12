require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/lock_races"

class Game::GrantAchievementConcurrencyTest < ActiveSupport::TestCase
  include GamePacks

  self.use_transactional_tests = false

  setup do
    @player = accounts_players(:player)
    create_pack(@player, opened_at: Time.current)
  end

  teardown do
    Game::AchievementUnlock.where(player_id: @player.id).delete_all
    Game::Pack.where(player_id: @player.id).delete_all
    stream = Game::Operation.stream_name(@player.id)
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
  end

  def grant_together
    gate = Queue.new
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          Game::GrantAchievement.new.call(player: Accounts::Player.find(@player.id), achievement: :first_booster)
        end
      end
    end
    2.times { gate << :go }
    threads.map { |thread| thread.join(20) ? thread.value : flunk("a thread is stuck: deadlock") }
  end

  test "two grants of the same achievement at once: one row, one event, the other refused" do
    results = grant_together

    assert_equal 1, results.count(&:success?)
    assert_equal [ :already_unlocked ], results.reject(&:success?).map(&:failure)
    assert_equal 1, Game::AchievementUnlock.where(player_id: @player.id).count
    assert_equal 1, game_events(@player, Game::AchievementUnlocked).size
  end
end

class Game::GrantAchievementDeletionConcurrencyTest < ActiveSupport::TestCase
  include GamePacks
  include LockRaces

  self.use_transactional_tests = false

  STEAM_ID = "76561197960299555".freeze

  setup do
    @player = Accounts::Player.create!(steam_id: STEAM_ID, persona_name: "Dana")
    create_pack(@player, opened_at: Time.current)
  end

  teardown do
    Game::AchievementUnlock.where(player_id: @player.id).delete_all
    Game::Pack.where(player_id: @player.id).delete_all
    streams = [ Game::Operation.stream_name(@player.id), "Accounts::Player$#{@player.id}" ]
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
    Accounts::Player.where(id: @player.id).delete_all
  end

  test "a grant that waits on the deletion's bank lock leaves no unlock and no event" do
    player = Accounts::Player.find(@player.id)

    deletion, grant = first_holding_the_lock(
      -> { Accounts::DeletePlayer.new.call(player: Accounts::Player.find(@player.id)) },
      -> { Game::GrantAchievement.new.call(player:, achievement: :first_booster) }
    )

    assert deletion.success?
    assert_equal Dry::Monads::Failure(:player_required), grant
    assert_not Game::AchievementUnlock.exists?(player_id: @player.id)
    assert_empty game_events(@player, Game::AchievementUnlocked)
  end
end
