module Accounts
  class ChangeReleaseNoteState < ApplicationOperation
    include ReleaseNoteWriting

    def call(staff:, release_note:, state:)
      note = step require_release_note(release_note)
      state = step require_state(state)

      transaction do
        note.lock!
        step require_complete_if_ready(state, note.texts)
        note.update!(state:)
        step publish_change(ReleaseNoteStateChanged.new(data: { release_note_id: note.id, staff_id: staff.id, state: }))
        note
      end
    end

    private

    def require_state(state)
      ReleaseNote.states.key?(state.to_s) ? Success(state.to_s) : Failure(:invalid_release_note_state)
    end
  end
end
