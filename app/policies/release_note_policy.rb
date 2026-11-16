class ReleaseNotePolicy < ApplicationPolicy
  def index? = player?
end
