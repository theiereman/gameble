class ExternalLinkOpenPolicy < ApplicationPolicy
  def create? = player?
end
