module BackOffice
  class RoadmapPolicy < ApplicationPolicy
    def show? = administrator?
    def update? = administrator?
    def preview? = administrator?
  end
end
