module Game
  # A contributor's reward for a reached weekly goal (CAP-12, AD-9): the
  # reward pack it granted. One row per player and week, unique in the
  # database, so a contributor is rewarded once whatever runs the grant.
  #
  # Written only through Game::GrantGoalReward (AD-3).
  class GoalReward < ApplicationRecord
    self.table_name = "game_goal_rewards"
  end
end
