module Market
  class SalePolicy < ApplicationPolicy
    def new? = true

    def create? = player?
  end
end
