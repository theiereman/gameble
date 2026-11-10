module BackOffice
  class MarketSignalsPolicy < ApplicationPolicy
    def show? = moderator?
  end
end
