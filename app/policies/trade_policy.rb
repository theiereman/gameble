# The trades screen and its answers. A visitor is refused and asked to sign
# in.
#
#   authorize :trade, :accept?
class TradePolicy < ApplicationPolicy
  # Any signed-in player reads their own trades and drafts one with a
  # friend; Game's queries and operations check the trade is theirs, whose
  # turn it is, and the friendship.
  def index? = player?
  def show? = player?
  def new? = player?
  def create? = player?
  def counter? = player?
  def accept? = player?
  def decline? = player?
  def cancel? = player?
end
