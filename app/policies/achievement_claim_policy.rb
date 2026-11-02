class AchievementClaimPolicy < ApplicationPolicy
  def create? = player?
end
