class InviteLinkPolicy < ApplicationPolicy
  def show? = true
  def create? = player?
end
