module BackOffice
  # Headless policy for the job queue (Mission Control Jobs): administrators
  # only. A visitor is asked to sign in; a player or moderator is refused (403).
  #
  #   authorize [ :back_office, :jobs ], :show?
  class JobsPolicy < ApplicationPolicy
    def show? = administrator?
  end
end
