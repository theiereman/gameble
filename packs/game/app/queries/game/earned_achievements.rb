module Game
  module EarnedAchievements
    LATEST = 4

    Earned = Data.define(:count, :total, :latest)

    def self.call(player)
      keys = player ? newest_first(player) : []
      Earned.new(count: keys.size, total: Achievements::CATALOGUE.size, latest: keys.first(LATEST).map { earned_tile(Achievements.find(it)) })
    end

    def self.newest_first(player)
      AchievementUnlock.where(player_id: player.id, achievement: Achievements::BY_KEY.keys)
        .order(unlocked_at: :desc, achievement: :asc).pluck(:achievement)
    end
    private_class_method :newest_first

    def self.earned_tile(achievement)
      AchievementBoard::Tile.new(key: achievement.key, threshold: achievement.threshold, progress: achievement.threshold, earned: true)
    end
    private_class_method :earned_tile
  end
end
