require "test_helper"

# Two duel stats computations started together: the second waits on the advisory lock until the first's transaction
# commits, then reads its rows. Each thread has its own connection, so the test commits for real and cleans up after itself.
class Game::ComputeDuelStatsConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    @release&.push(:go)
    @threads&.each { it.join(20) }
    Game::DuelStat.delete_all
    Game::FeedEntry.where(kind: "duel_stats").delete_all
    connection = ActiveRecord::Base.connection
    stream = Game::DuelStatsComputed::STREAM
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream = ?", stream ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
  end

  # A single bigint advisory key shows as classid (its high half), objid (its low half) and objsubid 1.
  WAITING = <<~SQL.squish
    SELECT count(*) FROM pg_locks
     WHERE locktype = 'advisory' AND NOT granted AND classid = 0 AND objid = :key AND objsubid = 1
       AND database = (SELECT oid FROM pg_database WHERE datname = current_database())
  SQL

  def waiting_on_the_duel_stats_lock?
    sql = ActiveRecord::Base.sanitize_sql_array([ WAITING, { key: Game::ComputeDuelStats::LOCK_KEY } ])
    ActiveRecord::Base.uncached { ActiveRecord::Base.connection.select_value(sql).positive? }
  end

  def in_thread(&block)
    Thread.new { ActiveRecord::Base.connection_pool.with_connection(&block) }
  end

  test "the second run waits for the first's transaction, then takes the percentiles it committed as the last weekly ones" do
    locked = Queue.new
    release = @release = Queue.new
    first = in_thread do
      ActiveRecord::Base.transaction do
        result = Game::ComputeDuelStats.new.call(reason: "first")
        Game::DuelStat.update_all(rating_percentile: 12.3)
        locked << :held
        release.pop
        result
      end
    end
    locked.pop
    second = in_thread { Game::ComputeDuelStats.new.call(reason: "weekly") }
    @threads = [ first, second ]

    Timeout.timeout(10) { sleep 0.01 until waiting_on_the_duel_stats_lock? }
    assert second.alive?, "the second run should wait for the first's lock"
    release << :go
    results = [ first, second ].map { |thread| thread.join(20) ? thread.value : flunk("a thread is stuck") }

    assert results.all?(&:success?)
    assert_equal %w[first weekly], Rails.configuration.event_store.read.stream(Game::DuelStatsComputed::STREAM).to_a.map { it.data[:reason] }
    weekly = Game::DuelStat.pluck(:rating_weekly_percentile)
    assert_equal 5, weekly.size
    assert_equal [ BigDecimal("12.3") ], weekly.uniq
  end
end
