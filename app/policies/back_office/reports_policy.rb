module BackOffice
  class ReportsPolicy < ApplicationPolicy
    def index? = moderator?
  end
end
