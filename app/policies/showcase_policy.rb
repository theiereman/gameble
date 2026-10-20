class ShowcasePolicy < ApplicationPolicy
  def create? = player?
  def update? = player?
  def destroy? = player?
end
