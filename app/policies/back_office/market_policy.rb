module BackOffice
  class MarketPolicy < ApplicationPolicy
    def show? = moderator?
  end
end
