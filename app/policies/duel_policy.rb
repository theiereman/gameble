class DuelPolicy < ApplicationPolicy
  def show? = player?
end
