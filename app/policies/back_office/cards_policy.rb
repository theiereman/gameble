module BackOffice
  class CardsPolicy < ApplicationPolicy
    def index? = administrator?
  end
end
