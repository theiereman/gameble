# The Friends screen (AD-14). A visitor is refused and asked to sign in.
#
#   authorize :friend, :show?
class FriendPolicy < ApplicationPolicy
  # Any signed-in player reads their own friends and code.
  def show? = player?
end
