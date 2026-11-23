class SlotPurchasePolicy < ApplicationPolicy
  def new? = player?

  def create? = player?
end
