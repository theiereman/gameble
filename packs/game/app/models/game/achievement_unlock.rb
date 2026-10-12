module Game
  class AchievementUnlock < ApplicationRecord
    self.table_name = "game_achievement_unlocks"

    def self.record(player_id, achievement, now)
      row = { player_id:, achievement: achievement.to_s, unlocked_at: now, created_at: now, updated_at: now }
      insert_all([ row ], unique_by: %i[player_id achievement], returning: :id, record_timestamps: false).rows.any?
    end
  end
end
