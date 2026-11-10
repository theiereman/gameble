module Market
  class EntrustmentPolicy < ApplicationPolicy
    def new? = true

    def create? = player?
  end
end
