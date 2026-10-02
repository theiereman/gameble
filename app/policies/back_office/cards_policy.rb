module BackOffice
  # Headless policy for the card preview: administrators only. A visitor is
  # asked to sign in; a player or moderator is refused (403).
  #
  #   authorize [ :back_office, :cards ], :index?
  class CardsPolicy < ApplicationPolicy
    def index? = administrator?
  end
end
