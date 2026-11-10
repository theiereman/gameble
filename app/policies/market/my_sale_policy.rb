module Market
  class MySalePolicy < ApplicationPolicy
    def show? = player?
  end
end
