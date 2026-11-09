module Accounts
  class SeeReleaseNoteJob < ActiveJob::Base
    queue_as :default

    def perform(player_id, release_note_id)
      SeeReleaseNote.new.call(player_id:, release_note_id:).value!
    end
  end
end
