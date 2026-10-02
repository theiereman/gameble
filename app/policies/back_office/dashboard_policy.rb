module BackOffice
  # Headless policy for the back-office: moderators and administrators only.
  # A visitor is asked to sign in; a player is refused (403).
  #
  #   authorize [ :back_office, :dashboard ], :show?
  class DashboardPolicy < ApplicationPolicy
    def show? = moderator?
  end
end
