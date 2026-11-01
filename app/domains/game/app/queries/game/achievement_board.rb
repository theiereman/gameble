module Game
  module AchievementBoard
    Tile = Data.define(:key, :threshold, :progress, :earned) do
      def countable? = threshold > 1
    end

    def self.call(player)
      unlocked = UnlockedAchievements.call(player)
      progress = AchievementProgress.call(player, Achievements.metrics(Achievements.unearned(unlocked)))
      Achievements::CATALOGUE.map do |achievement|
        unlocked.include?(achievement.key) ? earned_tile(achievement) : unearned_tile(achievement, progress)
      end
    end

    def self.earned_tile(achievement)
      Tile.new(key: achievement.key, threshold: achievement.threshold, progress: achievement.threshold, earned: true)
    end

    def self.unearned_tile(achievement, progress)
      Tile.new(key: achievement.key, threshold: achievement.threshold,
        progress: progress.fetch(achievement.metric).clamp(0, achievement.threshold), earned: false)
    end
    private_class_method :unearned_tile

    def self.summary(player)
      { earned: UnlockedAchievements.call(player).count { Achievements.find(it) }, total: Achievements::CATALOGUE.size }
    end
  end
end
