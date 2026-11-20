module Market
  class OrderCancellationPolicy < ApplicationPolicy
    def create? = player?
  end
end
