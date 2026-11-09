class RarityLegendPolicy < ApplicationPolicy
  def show? = player?
end
