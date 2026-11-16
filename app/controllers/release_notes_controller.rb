class ReleaseNotesController < ApplicationController
  def index
    authorize :release_note, :index?
    @release_notes = Accounts::ReleaseNotes.published(running: running_release)
  end
end
