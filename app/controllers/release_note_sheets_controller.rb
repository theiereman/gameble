class ReleaseNoteSheetsController < ApplicationController
  layout "sheet"

  def show
    authorize :release_note_sheet, :show?
    @release_note = Accounts::ReleaseNotes.live(running: running_release) or raise ActiveRecord::RecordNotFound
  end
end
