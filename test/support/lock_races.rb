# Operations raced on their own connections, for tests that commit for real
# (use_transactional_tests = false): either the first holds its transaction
# open until the second waits on a lock, then commits, or all start at once.
#
#   first, second = first_holding_the_lock(-> { ban }, -> { dismiss })
#   results = together(-> { open_pack }, -> { delete_player })
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

  # Removes what a test that committed for real left for these players.
  def purge_player_rows(players)
    connection = ActiveRecord::Base.connection
    tables = connection.tables.select { connection.column_exists?(it, :player_id) && it != "accounts_identities" }
    3.times do
      tables = tables.reject do |table|
        connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM #{connection.quote_table_name(table)} WHERE player_id IN (?)", players ]))
        true
      rescue ActiveRecord::InvalidForeignKey
        false
      end
    end
  end

  # Removes a committed market race's listing, its settings and every row of its players.
  def purge_market_race(players, listing:, settings:, card: nil)
    Game::Market::Bid.where(listing_id: listing.id).delete_all
    Game::Market::LedgerEntry.where(player_id: players).delete_all
    Game::Market::Wallet.where(player_id: players).delete_all
    Game::Market::Notice.where(listing_id: listing.id).delete_all
    Game::Market::Listing.where(id: listing.id).delete_all
    Game::Market::EditionPrice.where(card_season_id: card.id).delete_all if card
    purge_player_rows(players)
    purge_events(players)
    Game::Market::Settings.where(id: settings.id).delete_all
    Accounts::Player.where(id: players).delete_all
  end

  def purge_events(players)
    connection = ActiveRecord::Base.connection
    streams = players.flat_map { [ Game::Operation.stream_name(it), "Accounts::Player$#{it}" ] }
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
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
  # results in order; a thread that never returns fails the test, as a
  # deadlock would hang it. Once one thread fails, the others are stopped,
  # so none keeps its transaction and locks open into the teardown.
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
  ensure
    threads&.each { |thread| thread.kill.join(5) }
  end
end
