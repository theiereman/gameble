module Game
  module Market
    # Replaces the Archives' stocks with the sums of the deposits, in the database; rows belong to no player and no event is published.
    class SumArchiveStocks < ApplicationOperation
      UPSERT = <<~SQL.squish.freeze
        INSERT INTO game_market_archive_stocks (card_season_id, quantity, created_at, updated_at)
        SELECT card_season_id, SUM(quantity), :now, :now
        FROM game_market_archive_deposits
        GROUP BY card_season_id
        ORDER BY card_season_id
        ON CONFLICT (card_season_id) DO UPDATE
        SET quantity = EXCLUDED.quantity, updated_at = EXCLUDED.updated_at
        WHERE game_market_archive_stocks.quantity <> EXCLUDED.quantity
      SQL

      ORPHANS = <<~SQL.squish.freeze
        DELETE FROM game_market_archive_stocks
        WHERE NOT EXISTS (
          SELECT 1 FROM game_market_archive_deposits
          WHERE game_market_archive_deposits.card_season_id = game_market_archive_stocks.card_season_id
        )
      SQL

      def call(now: Time.current)
        transaction do
          changed = ArchiveStock.connection.exec_update(ArchiveStock.sanitize_sql([ UPSERT, { now: } ]))
          changed + ArchiveStock.connection.exec_delete(ORPHANS)
        end
      end
    end
  end
end
