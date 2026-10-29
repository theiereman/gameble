class SignInMethodPolicy < ApplicationPolicy
  def create? = player?
end
