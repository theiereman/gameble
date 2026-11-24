module Game
  module Market
    # Replaces the Archives' stocks with the deposits less the withdrawals and the copies their auctions hold or sold, in the database; rows
    # belong to no player and no event is published.
    class SumArchiveStocks < ApplicationOperation
      NET = <<~SQL.squish.freeze
        SELECT card_season_id, SUM(quantity) AS quantity
        FROM (
          SELECT card_season_id, quantity FROM game_market_archive_deposits
          UNION ALL
          SELECT card_season_id, -1 FROM game_market_archive_withdrawals
          UNION ALL
          SELECT card_season_id, -1 FROM game_market_listings WHERE seller_id IS NULL AND status IN ('open', 'sold')
        ) movements
        GROUP BY card_season_id
      SQL

      LOCK = "SELECT id FROM game_market_archive_stocks ORDER BY card_season_id FOR UPDATE".freeze

      UPSERT = <<~SQL.squish.freeze
        INSERT INTO game_market_archive_stocks (card_season_id, quantity, created_at, updated_at)
        SELECT card_season_id, quantity, :now, :now
        FROM (#{NET}) net
        WHERE quantity > 0
        ORDER BY card_season_id
        ON CONFLICT (card_season_id) DO UPDATE
        SET quantity = EXCLUDED.quantity, updated_at = EXCLUDED.updated_at
        WHERE game_market_archive_stocks.quantity <> EXCLUDED.quantity
      SQL

      EMPTIED = <<~SQL.squish.freeze
        DELETE FROM game_market_archive_stocks
        WHERE NOT EXISTS (
          SELECT 1 FROM (#{NET}) net
          WHERE net.card_season_id = game_market_archive_stocks.card_season_id AND net.quantity > 0
        )
      SQL

      def call(now: Time.current)
        transaction do
          connection = ArchiveStock.connection
          connection.select_values(LOCK)
          changed = connection.exec_update(ArchiveStock.sanitize_sql([ UPSERT, { now: } ]))
          changed + connection.exec_delete(EMPTIED)
        end
      end
    end
  end
end
