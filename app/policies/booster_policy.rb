# The booster screen (EXPERIENCE.md, Ouverture de booster; AD-14). A visitor
# is sent home and asked to sign in.
#
#   authorize :booster, :show?
class BoosterPolicy < ApplicationPolicy
  # Any signed-in player; the screen shows an empty reserve as such.
  def show? = player?
end
