class AchievementPolicy < ApplicationPolicy
  def show? = player?
end
