# Claiming a weekly goal reward. A visitor is refused and asked to sign in.
#
#   authorize :goal_reward, :create?
class GoalRewardPolicy < ApplicationPolicy
  # Any signed-in player; Game::ClaimGoalReward decides whether the reward
  # waits for them.
  def create? = player?
end
