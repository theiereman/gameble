module BackOffice
  # Headless policy for banning and unbanning players: moderators and
  # administrators. Whoever is not staff never reaches it: the back-office
  # answers them 404. Whom a ban reaches is the operations' rank rule.
  #
  #   authorize [ :back_office, :bans ], :create?
  class BansPolicy < ApplicationPolicy
    def index? = moderator?
    def create? = moderator?
    def destroy? = moderator?
  end
end
