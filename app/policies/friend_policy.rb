class FriendPolicy < ApplicationPolicy
  def show? = player?
end
