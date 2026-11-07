class PushDevicePolicy < ApplicationPolicy
  def create? = player?
end
