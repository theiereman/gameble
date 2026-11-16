class ProfileVisitPolicy < ApplicationPolicy
  def create? = player?
end
