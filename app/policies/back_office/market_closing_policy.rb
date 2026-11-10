module BackOffice
  class MarketClosingPolicy < ApplicationPolicy
    def create? = administrator?
  end
end
