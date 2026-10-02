# Headless policy for the public pages: everyone may read them (CAP-18).
#
#   authorize :page, :show?
class PagePolicy < ApplicationPolicy
  def show? = true
end
