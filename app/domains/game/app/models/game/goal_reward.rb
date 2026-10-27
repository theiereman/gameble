module Game
  # A contributor's reward for a reached weekly goal. One row per player and
  # week, unique in the database, so a contributor earns it once whatever runs
  # the grant. It waits without a pack until the player claims it; the claim
  # links the reward pack it drew, and a row with its pack is collected.
  #
  # Written only through Game::GrantGoalReward and Game::ClaimGoalReward.
  class GoalReward < ApplicationRecord
    self.table_name = "game_goal_rewards"

    scope :unclaimed, -> { where(pack_id: nil) }

    def claimed?
      pack_id.present?
    end
  end
end
