module Game
  module Market
    class PendingWantedRefresh < ApplicationRecord
      self.table_name = "game_market_pending_wanted_refreshes"
      self.primary_key = :player_id

      def self.mark(player_ids)
        return [] if player_ids.empty?

        insert_all(player_ids.map { { player_id: it } }, returning: :player_id).rows.flatten
      end
    end
  end
end
