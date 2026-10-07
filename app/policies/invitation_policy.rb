# Answering and sending friend invitations (AD-14). A visitor is refused and
# asked to sign in.
#
#   authorize :invitation, :accept?
class InvitationPolicy < ApplicationPolicy
  # Any signed-in player; Game's operations check the invitation is theirs.
  def create? = player?
  def accept? = player?
  def ignore? = player?
end
