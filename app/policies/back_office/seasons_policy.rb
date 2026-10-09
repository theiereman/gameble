module BackOffice
  # Headless policy for the catalog seasons: administrators only. Whoever
  # is not staff never reaches it (the back-office answers them 404); a
  # moderator is refused (403).
  #
  #   authorize [ :back_office, :seasons ], :publish?
  class SeasonsPolicy < ApplicationPolicy
    def index? = administrator?
    def publish? = administrator?
  end
end
