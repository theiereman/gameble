# A player's invite link (AD-14). Anyone may open it, a signed-out visitor
# included, who is then asked to sign in; sending the invitation needs a
# signed-in player.
#
#   authorize :invite_link, :show?
class InviteLinkPolicy < ApplicationPolicy
  def show? = true
  def create? = player?
end
