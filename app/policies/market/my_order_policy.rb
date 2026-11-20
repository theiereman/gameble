module Market
  class MyOrderPolicy < ApplicationPolicy
    def show? = player?
  end
end
