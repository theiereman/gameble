module Market
  class MyBidPolicy < ApplicationPolicy
    def show? = player?
  end
end
