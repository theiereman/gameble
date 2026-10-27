module Game
  class GoalReward < ApplicationRecord
    self.table_name = "game_goal_rewards"

    scope :unclaimed, -> { where(pack_id: nil) }

    def claimed?
      pack_id.present?
    end
  end
end
