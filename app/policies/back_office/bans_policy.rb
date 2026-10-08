module BackOffice
  class BansPolicy < ApplicationPolicy
    def create? = moderator?
    def destroy? = moderator?
  end
end
