module BackOffice
  class FeaturesPolicy < ApplicationPolicy
    def index? = administrator?
    def update? = administrator?
  end
end
