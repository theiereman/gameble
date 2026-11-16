class BellReadPolicy < ApplicationPolicy
  def create? = player?
end
