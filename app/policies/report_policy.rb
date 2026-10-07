# Reporting a player (AD-14). A visitor is refused and asked to sign in.
#
#   authorize :report, :create?
class ReportPolicy < ApplicationPolicy
  # Any signed-in player may report another; there is no record to name.
  def create? = player?
end
