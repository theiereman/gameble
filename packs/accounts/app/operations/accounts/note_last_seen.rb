module Accounts
  # Notes when a player was last seen (CAP-21, AD-24): `last_seen_at` moves
  # to `at`, the time of the request that saw them, at most once per
  # THROTTLE and only forward. A time in the future is taken as now. One
  # UPDATE of the player's own row (AD-9), which skips the write when the
  # stored time is less than THROTTLE older; `updated_at` is left alone.
  # Housekeeping: it publishes no event (AD-10).
  #
  # Run by Accounts::NoteLastSeenJob, which a request enqueues (a GET never
  # writes, AD-11).
  #
  #   Accounts::NoteLastSeen.new.call(player_id: 1, at: Time.current)
  #   # => Success(true) when written, Success(false) when throttled or the
  #   #    player is gone or banned | Failure(:invalid_time)
  class NoteLastSeen < ApplicationOperation
    # The least time between two writes for one player.
    THROTTLE = 1.minute

    def call(player_id:, at:)
      at = step check_time(at)

      transaction do
        at = [ at, Time.current ].min
        written = Player.where(id: player_id, banned_at: nil)
          .where("last_seen_at IS NULL OR last_seen_at <= ?", at - THROTTLE)
          .update_all(last_seen_at: at)
        written.positive?
      end
    end

    private

    # A Time or an ActiveSupport::TimeWithZone (which answers is_a?(Time)).
    def check_time(value)
      value.is_a?(Time) ? Success(value) : Failure(:invalid_time)
    end
  end
end
