class PagePolicy < ApplicationPolicy
  def show? = true
  def play? = player?
end
