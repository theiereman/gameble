class WelcomePolicy < ApplicationPolicy
  def destroy? = player?
end
