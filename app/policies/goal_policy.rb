class GoalPolicy < ApplicationPolicy
  def create? = player?
  def destroy? = player?
end
