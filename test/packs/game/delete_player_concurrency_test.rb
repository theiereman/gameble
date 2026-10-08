require "test_helper"
require_relative "../../support/game_packs"

# Deleting an account against an opening (AD-10, AD-14): the deletion
# releases the bank under the bank lock (Game::ReleasePlayer), and every
# bank operation re-checks the deletion once it holds that lock
# (Game::Operation#lock_bank). Whichever commits first, no row of the
# deleted player is left. Each thread has its own connection, so the test
# commits for real; it uses a player of its own and removes it afterwards.
class Game::DeletePlayerConcurrencyTest < ActiveSupport::TestCase
  include GamePacks

  self.use_transactional_tests = false

  setup do
    Game::DrawPool.reset!
    @player = Accounts::Player.create!(steam_id: "76561197960299878")
    Game::FillBank.new.call(player: @player).value!
  end

  teardown do
    id = @player.id
    Game::WeeklyGoal.where(week_start: Date.current.beginning_of_week).delete_all
    [ Game::FeedEntry, Game::DailyBonusClaim, Game::GoalReward, Game::FirstDiscovery, Game::Pack, Game::Holding, Game::SetCompletion,
      Game::FriendCode, Game::WeeklyContribution, Game::PlayerState ].each { |model| model.where(player_id: id).delete_all }
    connection = ActiveRecord::Base.connection
    streams = [ Game::Operation.stream_name(id), "Accounts::Player$#{id}" ]
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
    Accounts::Player.where(id:).delete_all
  end

  def leftovers
    id = @player.id
    { packs: Game::Pack.where(player_id: id).count, holdings: Game::Holding.where(player_id: id).count,
      feed: Game::FeedEntry.where(player_id: id).count, claims: Game::DailyBonusClaim.where(player_id: id).count,
      rewards: Game::GoalReward.where(player_id: id).count }
  end

  def none_left = { packs: 0, holdings: 0, feed: 0, claims: 0, rewards: 0 }

  # Runs `first` in a transaction that stays open until `second`, started on
  # another connection, waits on a lock; then commits it. Returns both
  # results.
  def first_holding_the_lock(first, second)
    held = Queue.new
    release = Queue.new
    first_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          first.call
        ensure
          # Raised or not, the main thread goes on; the transaction commits
          # only once released.
          held << true
          release.pop
        end
      end
    end
    held.pop
    second_thread = Thread.new { ActiveRecord::Base.connection_pool.with_connection { second.call } }
    begin
      wait_for_a_lock_wait
    ensure
      release << true
      results = [ first_thread.value, second_thread.value ]
    end
    results
  end

  # Until a session of this database waits on a lock.
  def wait_for_a_lock_wait
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
    waiting = "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database() AND wait_event_type = 'Lock'"
    until ActiveRecord::Base.uncached { ActiveRecord::Base.connection.select_value(waiting) }.positive?
      raise "the second operation never waited on a lock" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.01
    end
  end

  # Runs the blocks at once, each on its own connection, and returns their
  # results in order; a thread that never returns fails the test.
  def together(*blocks)
    gate = Queue.new
    threads = blocks.map do |block|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          block.call
        end
      end
    end
    blocks.size.times { gate << :go }
    threads.map { |thread| thread.join(20) ? thread.value : flunk("a thread is stuck: deadlock") }
  end

  def delete_player = -> { Accounts::DeletePlayer.new.call(player: Accounts::Player.find(@player.id)) }

  # The opening's player is read before the deletion, as a request would.
  def open_pack(player = Accounts::Player.find(@player.id)) = -> { Game::OpenPack.new.call(player:) }

  test "an opening that commits first: the deletion, waiting on the bank lock, then removes its rows" do
    opening, deletion = first_holding_the_lock(open_pack, delete_player)

    assert opening.success?
    assert deletion.success?
    assert_predicate @player.reload, :deleted?
    assert_equal none_left, leftovers
  end

  test "an opening that waits on the deletion's bank lock writes nothing" do
    player = Accounts::Player.find(@player.id)

    deletion, opening = first_holding_the_lock(delete_player, open_pack(player))

    assert deletion.success?
    assert_equal Dry::Monads::Failure(:player_required), opening
    assert_equal none_left, leftovers
  end

  test "a daily bonus, a fill, a heal or a goal reward that waits on the deletion writes nothing, not even a new bank" do
    week = Date.current.beginning_of_week
    Game::WeeklyGoal.create!(week_start: week, total: 1, target: 1)
    Game::WeeklyContribution.create!(player_id: @player.id, week_start: week, openings: 1)
    operations = {
      Game::CollectDailyBonus => {}, Game::FillBank => {}, Game::HealBank => {}, Game::GrantGoalReward => { week_start: week }
    }
    operations.each_with_index do |(operation, arguments), index|
      @player.update_columns(steam_id: "7656119796029#{9880 + index}", deleted_at: nil) if index.positive?
      player = Accounts::Player.find(@player.id)

      deletion, result = first_holding_the_lock(delete_player, -> { operation.new.call(player:, **arguments) })

      assert deletion.success?, operation.name
      assert_equal Dry::Monads::Failure(:player_required), result, operation.name
      assert_equal none_left, leftovers, operation.name
    end
  end

  test "openings and a deletion started together leave no row of the deleted player" do
    3.times { Game::OpenPack.new.call(player: @player) }
    player = Accounts::Player.find(@player.id)

    results = together(open_pack(player), open_pack(player), delete_player)

    assert results.last.success?
    results.first(2).select(&:failure?).each { |result| assert_includes %i[player_required no_pack_available], result.failure }
    assert_equal none_left, leftovers
  end

  test "a deletion, an opening, a bonus and a heal started together leave no row of the deleted player" do
    # A short bank of two available packs and three scheduled ones: the heal
    # has packs to add, and the reserve never fills before the bonus.
    Game::Pack.where(player_id: @player.id).delete_all
    2.times { |index| create_pack(@player, available_at: (index + 1).minutes.ago) }
    3.times { |index| create_pack(@player, available_at: (index + 1).minutes.from_now) }
    player = Accounts::Player.find(@player.id)
    bank_operations = [ Game::OpenPack, Game::CollectDailyBonus, Game::HealBank ]

    deletion, *results = together(delete_player, *bank_operations.map { |operation| -> { operation.new.call(player:) } })

    assert deletion.success?
    assert_predicate @player.reload, :deleted?
    results.zip(bank_operations).each do |result, operation|
      assert result.success? || result == Dry::Monads::Failure(:player_required), "#{operation.name}: #{result.inspect}"
    end
    assert_equal none_left, leftovers
  end
end
