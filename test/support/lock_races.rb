# Two operations raced on two connections, for tests that commit for real
# (use_transactional_tests = false): the first holds its transaction open
# until the second waits on a lock, then commits.
#
#   first, second = first_holding_the_lock(-> { ban }, -> { dismiss })
module LockRaces
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
end
