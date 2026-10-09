module BackOffice
  # Headless policy for the card preview: administrators only. Whoever is
  # not staff never reaches it (the back-office answers them 404); a
  # moderator is refused (403).
  #
  #   authorize [ :back_office, :cards ], :index?
  class CardsPolicy < ApplicationPolicy
    def index? = administrator?
  end
end
