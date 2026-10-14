class DataExportPolicy < ApplicationPolicy
  def show? = player?
  def create? = player?
end
