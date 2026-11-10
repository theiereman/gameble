module BackOffice
  class MarketHealthPolicy < ApplicationPolicy
    def show? = moderator?
  end
end
