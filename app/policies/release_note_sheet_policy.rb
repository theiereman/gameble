class ReleaseNoteSheetPolicy < ApplicationPolicy
  def show? = player?
end
