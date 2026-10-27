class SettingsPolicy < ApplicationPolicy
  def show? = player?
  def update? = player?
  def visibility? = player?
end
