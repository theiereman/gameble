module ReleaseNotesHelper
  # The running release when it has no note for players yet, to remind administrators on every page.
  def release_note_missing
    return @release_note_missing if defined?(@release_note_missing)

    @release_note_missing = (Accounts::ReleaseNotes.missing(running: running_release) if current_player&.administrator? && !hotwire_native_app?)
  end
end
