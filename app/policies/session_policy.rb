class SessionPolicy < ApplicationPolicy
  def create? = true
  def failure? = true
  def destroy? = player?
end
