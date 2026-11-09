module Accounts
  class CreateReleaseNote < ApplicationOperation
    include ReleaseNoteWriting

    def call(staff:, version:, state: "draft", **texts)
      version = step validate_version(version)
      texts = step validate_texts(texts)
      step require_complete_if_ready(state, texts)

      transaction do
        note = ReleaseNote.create_with(**texts, state:).find_or_create_by!(version: version.to_s)
        step require_new(note)
        step publish_change(ReleaseNoteCreated.new(data: { release_note_id: note.id, staff_id: staff.id, state: note.state }))
        note
      end
    rescue ActiveRecord::RecordNotUnique
      Failure(:release_version_taken)
    end

    private

    def validate_version(version)
      parsed = ReleaseVersion.parse(version)
      parsed ? Success(parsed) : Failure(:invalid_release_version)
    end

    def require_new(note)
      note.previously_new_record? ? Success(note) : Failure(:release_version_taken)
    end
  end
end
