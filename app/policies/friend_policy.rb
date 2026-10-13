class FriendPolicy < ApplicationPolicy
  def show? = player?
  def remove? = player?
end
