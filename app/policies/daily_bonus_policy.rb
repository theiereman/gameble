# Collecting the daily bonus (CAP-16, AD-14). A visitor is refused and asked
# to sign in.
#
#   authorize :daily_bonus, :create?
class DailyBonusPolicy < ApplicationPolicy
  # Any signed-in player; Game::CollectDailyBonus decides whether today's
  # bonus is still there.
  def create? = player?
end
