class ReactionPolicy < ApplicationPolicy
  def show? = true
  def create? = player?
  def destroy? = player?
end
