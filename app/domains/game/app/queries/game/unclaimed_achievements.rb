module Game
  module UnclaimedAchievements
    def self.keys(player)
      return Set.new unless player

      AchievementUnlock.unclaimed.where(player_id: player.id, achievement: Achievements::BY_KEY.keys).pluck(:achievement).to_set(&:to_sym)
    end

    def self.count(player)
      keys(player).size
    end
  end
end
