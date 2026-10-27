module BackOffice
  class BansPolicy < ApplicationPolicy
    def index? = moderator?
    def create? = moderator?
    def destroy? = moderator?
  end
end
