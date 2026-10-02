# Headless policy for the Steam sign-in and sign-out (AD-14). Anyone may start
# or finish a sign-in; only a player may sign out.
#
#   authorize :session
class SessionPolicy < ApplicationPolicy
  def create? = true
  def failure? = true
  def destroy? = player?
end
