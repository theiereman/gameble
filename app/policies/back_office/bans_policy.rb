module BackOffice
  # Headless policy for banning and unbanning players: moderators and
  # administrators. A visitor is asked to sign in; a player is refused (403).
  #
  #   authorize [ :back_office, :bans ], :create?
  class BansPolicy < ApplicationPolicy
    def index? = moderator?
    def create? = moderator?
    def destroy? = moderator?
  end
end
