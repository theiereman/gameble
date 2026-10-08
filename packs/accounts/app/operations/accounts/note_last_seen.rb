module Accounts
  class NoteLastSeen < ApplicationOperation
    THROTTLE = 1.minute

    def call(player_id:, at:)
      at = step check_time(at)

      transaction do
        at = [ at, Time.current ].min
        written = Player.in_good_standing.where(id: player_id)
          .where("last_seen_at IS NULL OR last_seen_at <= ?", at - THROTTLE)
          .update_all(last_seen_at: at)
        written.positive?
      end
    end

    private

    def check_time(value)
      value.is_a?(Time) ? Success(value) : Failure(:invalid_time)
    end
  end
end
