class CollectionSeenPolicy < ApplicationPolicy
  def create? = player?
end
