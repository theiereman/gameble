module Market
  class BidPolicy < ApplicationPolicy
    def create? = player?
  end
end
