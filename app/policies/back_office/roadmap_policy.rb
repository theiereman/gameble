module BackOffice
  class RoadmapPolicy < ApplicationPolicy
    def show? = administrator?
    def update? = administrator?
    def preview? = administrator?
    def translate? = administrator?
  end
end
