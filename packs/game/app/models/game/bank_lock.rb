module Game
  # Lock order: bank locks in ascending player id, then holdings by player and card season, then game_player_states rows.
  module BankLock
    # "GAME" in ASCII: the advisory locks of this pack.
    NAMESPACE = 0x47414D45

    # Must run inside a transaction. A player id beyond the int4 range wraps
    # around: two such players may share a lock, which only serialises them.
    def self.acquire(player_id)
      key = ((Integer(player_id) + 2**31) % 2**32) - 2**31
      ApplicationRecord.connection.execute(
        ApplicationRecord.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(?, ?)", NAMESPACE, key ])
      )
    end
  end
end
