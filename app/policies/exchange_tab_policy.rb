class ExchangeTabPolicy < ApplicationPolicy
  def create? = player?
end
