class DailyBonusPolicy < ApplicationPolicy
  def create? = player?
end
