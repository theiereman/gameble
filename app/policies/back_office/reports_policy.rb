module BackOffice
  # Headless policy for the queue of reported players: moderators and
  # administrators. Whoever is not staff never reaches it: the back-office
  # answers them 404.
  #
  #   authorize [ :back_office, :reports ], :dismiss?
  class ReportsPolicy < ApplicationPolicy
    def index? = moderator?
    def dismiss? = moderator?
  end
end
