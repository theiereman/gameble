module Game
  # The lock of a player's bank (AD-7): a transaction-level advisory lock on
  # (NAMESPACE, player id), released at commit or rollback. Every operation
  # that changes a player's bank takes it first, so openings, fills,
  # replacements and bonuses of one player run one at a time. Lock order:
  # the bank, then the holdings in ascending card-season.
  #
  #   transaction do
  #     Game::BankLock.acquire(player.id)
  #     …
  #   end
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
