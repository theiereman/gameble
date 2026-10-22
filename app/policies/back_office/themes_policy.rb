module BackOffice
  # Headless policy for the catalog's themes and the classification of Steam
  # tags: administrators only. Whoever is not staff never reaches it (the
  # back-office answers them 404); a moderator is refused (403).
  #
  #   authorize [ :back_office, :themes ], :attach?
  class ThemesPolicy < ApplicationPolicy
    def index? = administrator?
    def create? = administrator?
    def update? = administrator?
    def attach? = administrator?
    def dismiss? = administrator?
  end
end
