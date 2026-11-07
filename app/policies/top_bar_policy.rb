class TopBarPolicy < ApplicationPolicy
  def show? = player?
end
