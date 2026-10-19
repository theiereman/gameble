module BackOffice
  # Headless policy for the landing's roadmap: administrators only. Whoever
  # is not staff never reaches it (the back-office answers them 404); a
  # moderator is refused (403).
  #
  #   authorize [ :back_office, :roadmap ], :update?
  class RoadmapPolicy < ApplicationPolicy
    def index? = administrator?
    def new? = administrator?
    def create? = administrator?
    def edit? = administrator?
    def update? = administrator?
    def move? = administrator?
    def destroy? = administrator?
  end
end
