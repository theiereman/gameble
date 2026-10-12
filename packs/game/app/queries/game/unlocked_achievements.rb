module Game
  module UnlockedAchievements
    def self.call(player)
      return Set.new unless player

      AchievementUnlock.where(player_id: player.id).pluck(:achievement).to_set(&:to_sym)
    end
  end
end
