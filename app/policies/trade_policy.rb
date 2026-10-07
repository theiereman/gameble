# The trades screen and its answers (AD-14). A visitor is refused and asked
# to sign in.
#
#   authorize :trade, :accept?
class TradePolicy < ApplicationPolicy
  # Any signed-in player reads their own trades; Game's queries and
  # operations check the trade is theirs and whose turn it is.
  def index? = player?
  def show? = player?
  def counter? = player?
  def accept? = player?
  def decline? = player?
  def cancel? = player?
end
