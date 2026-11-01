class PackRevealPolicy < ApplicationPolicy
  def create? = player?
end
