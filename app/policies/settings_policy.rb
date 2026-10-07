# The player's settings screen (AD-14). A visitor is refused and asked to
# sign in.
#
#   authorize :settings, :show?
class SettingsPolicy < ApplicationPolicy
  # Any signed-in player reads and changes their own settings; there is no
  # record to name.
  def show? = player?
  def update? = player?
  def visibility? = player?
end
