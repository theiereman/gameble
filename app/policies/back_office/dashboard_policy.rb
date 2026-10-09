module BackOffice
  # Headless policy for the back-office: moderators and administrators only.
  # Whoever is not staff never reaches it: the back-office answers them 404.
  #
  #   authorize [ :back_office, :dashboard ], :show?
  class DashboardPolicy < ApplicationPolicy
    def show? = moderator?
  end
end
