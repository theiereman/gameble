module Game
  class AchievementUnlock < ApplicationRecord
    self.table_name = "game_achievement_unlocks"

    scope :unclaimed, -> { where(claimed_at: nil) }
    scope :claimed, -> { where.not(claimed_at: nil) }

    def self.record(player_id, achievement, now, claimed: true)
      row = { player_id:, achievement: achievement.to_s, unlocked_at: now, claimed_at: (now if claimed), created_at: now, updated_at: now }
      insert_all([ row ], unique_by: %i[player_id achievement], returning: :id, record_timestamps: false).rows.any?
    end
  end
end
