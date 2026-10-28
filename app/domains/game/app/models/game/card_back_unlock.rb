module Game
  class CardBackUnlock < ApplicationRecord
    self.table_name = "game_card_back_unlocks"

    def self.record(player_id, back, now)
      row = { player_id:, back: back.to_s, unlocked_at: now, created_at: now, updated_at: now }
      insert_all([ row ], unique_by: %i[player_id back], returning: :id, record_timestamps: false).rows.any?
    end
  end
end
