module BackOffice
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
