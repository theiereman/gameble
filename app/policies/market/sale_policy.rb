module Market
  class SalePolicy < ApplicationPolicy
    def new? = true

    def create? = player?

    def sell? = player?
  end
end
