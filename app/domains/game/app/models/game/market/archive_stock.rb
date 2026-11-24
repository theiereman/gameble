module Game
  module Market
    # The copies of one edition the Archives keep: a derived sum of the deposits, which no per-player write touches.
    class ArchiveStock < ApplicationRecord
      self.table_name = "game_market_archive_stocks"

      # One copy leaves a locked stock row; its last copy takes the row away.
      def take_one(now)
        quantity == 1 ? delete : self.class.where(id:).update_all([ "quantity = quantity - 1, updated_at = ?", now ])
      end

      def self.give_back(card_season_id, now)
        upsert({ card_season_id:, quantity: 1, created_at: now, updated_at: now }, unique_by: :card_season_id, record_timestamps: false,
          on_duplicate: Arel.sql("quantity = game_market_archive_stocks.quantity + 1, updated_at = EXCLUDED.updated_at"))
      end
    end
  end
end
