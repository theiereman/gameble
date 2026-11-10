module BackOffice
  class MarketOpeningPolicy < ApplicationPolicy
    def create? = administrator?
  end
end
