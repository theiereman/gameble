# Headless policy for pages: an open page anyone may read, a page of the
# game itself only a signed-in player may.
#
#   authorize :page, :show?
#   authorize :page, :play?
class PagePolicy < ApplicationPolicy
  def show? = true
  def play? = player?
end
