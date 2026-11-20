module BackOffice
  class DuelsPolicy < ApplicationPolicy
    def show? = moderator?
  end
end
