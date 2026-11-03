class CardTradePolicy < ApplicationPolicy
  def create? = player?
end
