module Market
  class WantedChoicePolicy < ApplicationPolicy
    def new? = player?

    def create? = player?
  end
end
