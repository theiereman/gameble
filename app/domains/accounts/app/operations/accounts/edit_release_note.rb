module Accounts
  class EditReleaseNote < ApplicationOperation
    include ReleaseNoteWriting

    def call(staff:, release_note:, **texts)
      note = step require_release_note(release_note)
      texts = step validate_texts(texts)

      transaction do
        note.lock!
        step require_complete_if_ready(note.state, texts)
        note.update!(texts)
        step publish_change(ReleaseNoteEdited.new(data: { release_note_id: note.id, staff_id: staff.id }))
        note
      end
    end
  end
end
