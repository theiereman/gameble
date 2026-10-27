module BackOffice
  class ReportsPolicy < ApplicationPolicy
    def index? = moderator?
    def dismiss? = moderator?
  end
end
