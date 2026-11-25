module Market
  class OrderPolicy < ApplicationPolicy
    def new? = player?

    def create? = player?

    def update? = player?
  end
end
