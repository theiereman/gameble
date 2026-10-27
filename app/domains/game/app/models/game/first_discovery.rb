module Game
  class FirstDiscovery < ApplicationRecord
    self.table_name = "game_first_discoveries"

    def self.record(pack, now)
      rows = pack.card_season_ids.uniq.sort.map do |card_season_id|
        { card_season_id:, player_id: pack.player_id, pack_id: pack.id, discovered_at: now, created_at: now, updated_at: now }
      end
      insert_all(rows, unique_by: :card_season_id, returning: :card_season_id, record_timestamps: false)
        .rows.flatten.sort
    end
  end
end
