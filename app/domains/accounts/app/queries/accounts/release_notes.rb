module Accounts
  module ReleaseNotes
    def self.newest_first
      ReleaseNote.all.sort_by(&:release_version).reverse
    end

    def self.by_token(token)
      ReleaseNote.find_by(token: token.to_s)
    end

    def self.by_version(version)
      ReleaseNote.find_by(version: version.to_s.strip)
    end

    def self.read_counts(notes)
      ReleaseNoteRead.where(release_note_id: notes.map(&:id)).group(:release_note_id).count
    end

    # The note production shows now: the newest ready one written for the running release or one before it.
    def self.live(running:)
      return unless running

      ReleaseNote.ready.select { it.release_version <= running }.max_by(&:release_version)
    end

    def self.unseen_by(player, running:)
      note = live(running:)
      note if note && player && !ReleaseNoteRead.exists?(release_note_id: note.id, player_id: player.id)
    end

    # The running release when no note was made ready for it nor marked as needing none.
    def self.missing(running:)
      running if running && !ReleaseNote.where(version: running.to_s, state: %w[ready skipped]).exists?
    end
  end
end
