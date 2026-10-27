class BoosterPolicy < ApplicationPolicy
  def show? = player?
end
