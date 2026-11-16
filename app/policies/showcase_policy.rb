class ShowcasePolicy < ApplicationPolicy
  def edit? = player?
  def create? = player?
  def update? = player?
  def destroy? = player?
end
