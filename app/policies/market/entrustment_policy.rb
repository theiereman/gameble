module Market
  class EntrustmentPolicy < ApplicationPolicy
    def new? = true

    def matching? = true

    def create? = player?
  end
end
