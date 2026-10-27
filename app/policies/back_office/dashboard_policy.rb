module BackOffice
  class DashboardPolicy < ApplicationPolicy
    def show? = moderator?
  end
end
