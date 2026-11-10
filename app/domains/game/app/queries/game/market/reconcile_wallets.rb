module Game
  module Market
    # Compares every wallet with the sum of its entries, and all entries with what was minted less what was destroyed.
    # Reads only, in one snapshot; nothing is repaired.
    module ReconcileWallets
      WALLET_DIFFERENCES = <<~SQL.squish.freeze
        SELECT COALESCE(wallets.player_id, entries.player_id) AS player_id,
               COALESCE(wallets.available, 0) AS wallet_available,
               COALESCE(wallets.committed, 0) AS wallet_committed,
               COALESCE(entries.available, 0) AS entries_available,
               COALESCE(entries.committed, 0) AS entries_committed
        FROM game_market_wallets wallets
        FULL OUTER JOIN (
          SELECT player_id, SUM(available_delta) AS available, SUM(committed_delta) AS committed
          FROM game_market_ledger_entries GROUP BY player_id
        ) entries ON entries.player_id = wallets.player_id
        WHERE COALESCE(wallets.available, 0) <> COALESCE(entries.available, 0)
           OR COALESCE(wallets.committed, 0) <> COALESCE(entries.committed, 0)
        ORDER BY 1
      SQL

      TOTALS = <<~SQL.squish.freeze
        SELECT COALESCE(SUM(available_delta + committed_delta), 0) AS circulation,
               COALESCE(SUM(available_delta) FILTER (WHERE kind = 'mint'), 0) AS minted,
               COALESCE(-SUM(available_delta) FILTER (WHERE kind IN ('stamp', 'commission', 'forfeit')), 0) AS destroyed
        FROM game_market_ledger_entries
      SQL

      def self.call
        ActiveRecord::Base.transaction(isolation: :repeatable_read, joinable: false) do
          connection = ActiveRecord::Base.connection
          rows = connection.select_all(WALLET_DIFFERENCES).to_a
          totals = connection.select_one(TOTALS)
          Reconciliation.new(
            wallet_differences: rows.map { |row| Reconciliation::WalletDifference.new(**row.symbolize_keys.transform_values(&:to_i)) },
            minted: totals.fetch("minted").to_i, destroyed: totals.fetch("destroyed").to_i, circulation: totals.fetch("circulation").to_i,
            read_at: Time.current
          )
        end
      end
    end
  end
end
