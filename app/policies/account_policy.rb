class AccountPolicy < ApplicationPolicy
  def destroy? = player?
end
