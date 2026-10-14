class DataExportPolicy < ApplicationPolicy
  def create? = player?
end
