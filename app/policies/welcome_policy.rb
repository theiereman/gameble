# Closing the welcome panel. A visitor is refused and asked to sign in.
#
#   authorize :welcome, :destroy?
class WelcomePolicy < ApplicationPolicy
  # Any signed-in player closes their own welcome; a player who has none
  # closes nothing.
  def destroy? = player?
end
