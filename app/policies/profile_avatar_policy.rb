class ProfileAvatarPolicy < ApplicationPolicy
  def update? = player?
end
