module BackOffice
  class MarketSettingPolicy < ApplicationPolicy
    def create? = administrator?
  end
end
