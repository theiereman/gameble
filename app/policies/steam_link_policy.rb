class SteamLinkPolicy < ApplicationPolicy
  def create? = player?
end
