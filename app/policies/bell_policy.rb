class BellPolicy < ApplicationPolicy
  def show? = player?
end
