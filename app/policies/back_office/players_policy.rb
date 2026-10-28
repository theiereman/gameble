module BackOffice
  class PlayersPolicy < ApplicationPolicy
    def index? = moderator?
    def destroy? = administrator?
  end
end
