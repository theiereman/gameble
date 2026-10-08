class InvitationPolicy < ApplicationPolicy
  def create? = player?
  def accept? = player?
  def ignore? = player?
end
