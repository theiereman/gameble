module Accounts
  module ReleaseNoteWriting
    private

    def validate_texts(texts)
      texts = ReleaseNote.clean(texts)
      ReleaseNote.fitting?(texts) ? Success(texts) : Failure(:invalid_release_note)
    end

    def require_release_note(release_note)
      release_note.is_a?(ReleaseNote) && release_note.persisted? ? Success(release_note) : Failure(:release_note_not_found)
    end

    def require_complete_if_ready(state, texts)
      state.to_s != "ready" || ReleaseNote.complete?(texts) ? Success(state) : Failure(:incomplete_release_note)
    end

    def publish_change(event)
      publish(event, stream_name: ReleaseNote.stream_name)
    end
  end
end
