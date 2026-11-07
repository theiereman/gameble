class BoosterPolicy < ApplicationPolicy
  def show? = player?

  def next_steps? = player?
end
