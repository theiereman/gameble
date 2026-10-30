module Game
  module AchievementBoard
    Tile = Data.define(:key, :threshold, :progress, :earned, :ready) do
      def countable? = threshold > 1
    end

    def self.call(player)
      progress = AchievementProgress.call(player)
      unlocked = UnlockedAchievements.call(player)
      collected = CollectedAchievements.call(player)
      Achievements::CATALOGUE.map do |achievement|
        Tile.new(key: achievement.key, threshold: achievement.threshold,
          progress: progress.fetch(achievement.metric).clamp(0, achievement.threshold),
          earned: collected.include?(achievement.key), ready: unlocked.include?(achievement.key) && !collected.include?(achievement.key))
      end
    end

    def self.summary(player)
      { earned: CollectedAchievements.call(player).count { Achievements.find(it) }, total: Achievements::CATALOGUE.size }
    end
  end
end
