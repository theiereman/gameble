class TradeSeenPolicy < ApplicationPolicy
  def create? = player?
end
