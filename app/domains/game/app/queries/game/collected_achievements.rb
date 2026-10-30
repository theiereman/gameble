module Game
  module CollectedAchievements
    def self.call(player)
      return Set.new unless player

      AchievementUnlock.collected.where(player_id: player.id).pluck(:achievement).to_set(&:to_sym)
    end
  end
end
