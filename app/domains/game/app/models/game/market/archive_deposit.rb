module Game
  module Market
    # The copies of one edition a player has entrusted to the Archives. Players are anonymised, never deleted, so a deposit outlives its account.
    class ArchiveDeposit < ApplicationRecord
      self.table_name = "game_market_archive_deposits"

      def self.add(player_id, quantities, now)
        rows = quantities.map { |card_season_id, quantity| { player_id:, card_season_id:, quantity:, created_at: now, updated_at: now } }
        upsert_all(rows, unique_by: %i[player_id card_season_id], record_timestamps: false,
          on_duplicate: Arel.sql("quantity = game_market_archive_deposits.quantity + EXCLUDED.quantity, updated_at = EXCLUDED.updated_at"))
      end
    end
  end
end
