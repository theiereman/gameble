module Accounts
  # Writes a player's last-seen time outside the request that saw them
  # (CAP-21, AD-24): a GET never writes (AD-11), so the request enqueues this
  # job, at most about once a minute per player
  # (ApplicationController#note_presence), and Accounts::NoteLastSeen
  # throttles the write again.
  class NoteLastSeenJob < ActiveJob::Base
    queue_as :default

    def perform(player_id, seen_at)
      NoteLastSeen.new.call(player_id:, at: seen_at).value!
    end
  end
end
