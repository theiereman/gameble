class MotionPolicy < ApplicationPolicy
  def create? = visitor?
end
