class OwnProfilePolicy < ApplicationPolicy
  def show? = player?
end
