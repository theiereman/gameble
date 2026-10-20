class ShowcasePolicy < ApplicationPolicy
  def create? = player?
  def destroy? = player?
end
