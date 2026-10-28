class CardBackPolicy < ApplicationPolicy
  def update? = player?
end
