module BackOffice
  class PlayersPolicy < ApplicationPolicy
    def index? = moderator?
  end
end
