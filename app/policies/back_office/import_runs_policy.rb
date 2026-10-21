module BackOffice
  # Headless policy for the Steam import runs: administrators only. Whoever
  # is not staff never reaches it (the back-office answers them 404); a
  # moderator is refused (403).
  #
  #   authorize [ :back_office, :import_runs ], :index?
  class ImportRunsPolicy < ApplicationPolicy
    def index? = administrator?
    def show? = administrator?
    def create? = administrator?
    def resume? = administrator?
    def rescore? = administrator?
    def abandon? = administrator?
    def promote? = administrator?
    def discard? = administrator?
  end
end
