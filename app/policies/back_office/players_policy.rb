module BackOffice
  # Headless policy for the list of players: moderators and administrators.
  # Whoever is not staff never reaches it: the back-office answers them 404.
  #
  #   authorize [ :back_office, :players ], :index?
  class PlayersPolicy < ApplicationPolicy
    def index? = moderator?
  end
end
