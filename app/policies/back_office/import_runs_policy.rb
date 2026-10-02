module BackOffice
  # Headless policy for the Steam import runs (AD-19): administrators only.
  # A visitor is asked to sign in; a player or moderator is refused (403).
  #
  #   authorize [ :back_office, :import_runs ], :index?
  class ImportRunsPolicy < ApplicationPolicy
    def index? = administrator?
    def show? = administrator?
    def create? = administrator?
    def resume? = administrator?
    def rescore? = administrator?
  end
end
