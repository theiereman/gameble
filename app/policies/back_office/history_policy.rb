module BackOffice
  class HistoryPolicy < ApplicationPolicy
    def index? = moderator?
  end
end
