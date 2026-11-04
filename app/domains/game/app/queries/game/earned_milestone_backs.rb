module Game
  module EarnedMilestoneBacks
    def self.call(player)
      AchievementUnlock.claimed.where(player_id: player.id).pluck(:achievement).filter_map { CardBacks::ACHIEVEMENT_BACKS[it] }
    end
  end
end
