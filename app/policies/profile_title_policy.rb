class ProfileTitlePolicy < ApplicationPolicy
  def update? = player?
end
