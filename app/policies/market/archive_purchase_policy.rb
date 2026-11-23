module Market
  class ArchivePurchasePolicy < ApplicationPolicy
    def new? = player?

    def create? = player?
  end
end
