module Market
  class BuyerPolicy < ApplicationPolicy
    def show? = player?
  end
end
