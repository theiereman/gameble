module Game
  # Lock order: bank locks in ascending player id, then holdings by player and card season, then game_player_states rows.
  module BankLock
    NAMESPACE = 0x47414D45

    def self.acquire(player_id)
      ApplicationRecord.connection.execute(
        ApplicationRecord.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(?, ?)", NAMESPACE, key(player_id) ])
      )
    end

    # pg_locks shows a two-key advisory lock with its keys as unsigned oids and objsubid 2.
    def self.held?(player_id)
      ApplicationRecord.connection.select_value(ApplicationRecord.sanitize_sql_array([ <<~SQL.squish, NAMESPACE, key(player_id) % 2**32 ]))
        SELECT EXISTS (SELECT 1 FROM pg_locks WHERE locktype = 'advisory' AND pid = pg_backend_pid() AND granted
          AND classid = ?::bigint::oid AND objid = ?::bigint::oid AND objsubid = 2)
      SQL
    end

    # A player id beyond the int4 range wraps around: two such players may share a lock, which only serialises them.
    def self.key(player_id) = ((Integer(player_id) + 2**31) % 2**32) - 2**31
    private_class_method :key
  end
end
