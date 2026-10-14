class PacksChipPolicy < ApplicationPolicy
  def show? = player?
end
