class RepostPolicy < ApplicationPolicy
  def create? = player?
end
