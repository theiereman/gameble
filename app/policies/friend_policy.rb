# The Friends screen and a friend's profile (AD-14). A visitor is refused
# and asked to sign in; whether the profile's owner is a friend is Game's
# to answer (FriendProfilesController).
#
#   authorize :friend, :show?
class FriendPolicy < ApplicationPolicy
  # Any signed-in player reads their own friends and code, and opens a
  # friend's profile.
  def show? = player?
end
