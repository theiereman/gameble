module Game
  module EarnedMilestoneBacks
    def self.call(player)
      goal = GoalReward.exists?(player_id: player.id) ? [ CardBacks::GOAL_BACK ] : []
      achievements = UnlockedAchievements.call(player).filter_map { CardBacks::ACHIEVEMENT_BACKS[it.to_s] }
      goal + achievements
    end
  end
end
