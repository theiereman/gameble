class GoalRewardPolicy < ApplicationPolicy
  def create? = player?
end
