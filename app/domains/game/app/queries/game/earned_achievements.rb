module Game
  module EarnedAchievements
    LATEST = 4

    Earned = Data.define(:count, :total, :latest)

    def self.call(player)
      offered = Achievements.offered
      keys = player ? newest_first(player, Achievements.offered_keys(offered)) : []
      Earned.new(count: keys.size, total: offered.size, latest: keys.first(LATEST).map { AchievementBoard.earned_tile(Achievements.find(it)) })
    end

    def self.newest_first(player, offered_keys)
      AchievementUnlock.where(player_id: player.id, achievement: offered_keys)
        .order(unlocked_at: :desc, achievement: :asc).pluck(:achievement)
    end
    private_class_method :newest_first
  end
end
