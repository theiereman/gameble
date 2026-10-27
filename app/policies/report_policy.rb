class ReportPolicy < ApplicationPolicy
  def create? = player?
end
