module BackOffice
  # Headless policy for the queue of reported players: moderators and
  # administrators. A visitor is asked to sign in; a player is refused (403).
  #
  #   authorize [ :back_office, :reports ], :dismiss?
  class ReportsPolicy < ApplicationPolicy
    def index? = moderator?
    def dismiss? = moderator?
  end
end
