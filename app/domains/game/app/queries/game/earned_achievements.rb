module Game
  module EarnedAchievements
    LATEST = 4

    Earned = Data.define(:count, :total, :latest, :ready)

    def self.call(player)
      collected, ready = player ? newest_first(player).partition(&:last) : [ [], [] ]
      keys = collected.map(&:first)
      Earned.new(count: keys.size, total: Achievements::CATALOGUE.size, latest: keys.first(LATEST).map { earned_tile(Achievements.find(it)) },
        ready: ready.size)
    end

    def self.newest_first(player)
      AchievementUnlock.where(player_id: player.id, achievement: Achievements::BY_KEY.keys)
        .order(collected_at: :desc, achievement: :asc).pluck(:achievement, :collected_at)
    end
    private_class_method :newest_first

    def self.earned_tile(achievement)
      AchievementBoard::Tile.new(key: achievement.key, threshold: achievement.threshold, progress: achievement.threshold, earned: true, ready: false)
    end
    private_class_method :earned_tile
  end
end
