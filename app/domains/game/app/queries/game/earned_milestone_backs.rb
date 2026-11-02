module Game
  module EarnedMilestoneBacks
    def self.call(player)
      goal = GoalReward.exists?(player_id: player.id) ? [ CardBacks::GOAL_BACK ] : []
      achievements = AchievementUnlock.claimed.where(player_id: player.id).pluck(:achievement).filter_map { CardBacks::ACHIEVEMENT_BACKS[it] }
      goal + achievements
    end
  end
end
