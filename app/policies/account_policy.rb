# The signed-in player's own account (AD-14). A visitor is refused and asked
# to sign in.
#
#   authorize :account, :destroy?
class AccountPolicy < ApplicationPolicy
  # Any signed-in player may delete their own account; there is no record to
  # name.
  def destroy? = player?
end
