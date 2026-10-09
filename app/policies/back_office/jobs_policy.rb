module BackOffice
  # Headless policy for the job queue (Mission Control Jobs): administrators
  # only. Whoever is not staff never reaches it (the back-office answers them
  # 404); a moderator is refused (403).
  #
  #   authorize [ :back_office, :jobs ], :show?
  class JobsPolicy < ApplicationPolicy
    def show? = administrator?
  end
end
