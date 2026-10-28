class SeasonAllocationPolicy < ApplicationPolicy
  def show? = player?
  def create? = player?
end
