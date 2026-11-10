class FriendPolicy < ApplicationPolicy
  def show? = player?
  def remove? = player?
  def search? = player?
end
