class PersonalizationPolicy < ApplicationPolicy
  def show? = player?
end
