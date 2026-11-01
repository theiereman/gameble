class TradeSuggestionPolicy < ApplicationPolicy
  def create? = player?
end
