module BackOffice
  # Headless policy for the catalog seasons (AD-5): administrators only.
  # A visitor is asked to sign in; a player or moderator is refused (403).
  #
  #   authorize [ :back_office, :seasons ], :publish?
  class SeasonsPolicy < ApplicationPolicy
    def index? = administrator?
    def publish? = administrator?
  end
end
