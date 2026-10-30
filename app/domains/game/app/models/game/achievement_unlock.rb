module Game
  class AchievementUnlock < ApplicationRecord
    self.table_name = "game_achievement_unlocks"

    scope :collected, -> { where.not(collected_at: nil) }
    scope :ready, -> { where(collected_at: nil) }

    def self.record(player_id, achievement, now)
      row = { player_id:, achievement: achievement.to_s, unlocked_at: now, created_at: now, updated_at: now }
      insert_all([ row ], unique_by: %i[player_id achievement], returning: :id, record_timestamps: false).rows.any?
    end

    def self.collect(player_id, achievement, now)
      ready.where(player_id:, achievement: achievement.to_s).update_all(collected_at: now, updated_at: now) == 1
    end
  end
end
