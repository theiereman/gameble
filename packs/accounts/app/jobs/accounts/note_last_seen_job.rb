module Accounts
  class NoteLastSeenJob < ActiveJob::Base
    queue_as :default

    def perform(player_id, seen_at)
      NoteLastSeen.new.call(player_id:, at: seen_at).value!
    end
  end
end
