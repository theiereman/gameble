class AchievementPolicy < ApplicationPolicy
  def show? = player?

  def collect? = player?
end
