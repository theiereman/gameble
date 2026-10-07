module Game
  # A player's contribution to the weekly goal (CAP-12, AD-9): one row per
  # player and week, unique in the database. `openings` counts the packs the
  # player opened that week. Written only by Game::Handlers::PackOpened, in
  # the opening's transaction, and only for the opener (AD-10).
  class WeeklyContribution < ApplicationRecord
    self.table_name = "game_weekly_contributions"

    # Counts one more opening for the player in the week of `now`, creating
    # the row on the first one: a single upsert that never fails on a
    # duplicate.
    def self.record_opening(player_id, now)
      stamp = now.utc
      upsert({ player_id:, week_start: WeeklyGoal.week_start(stamp), openings: 1, created_at: stamp, updated_at: stamp },
        unique_by: %i[player_id week_start], record_timestamps: false,
        on_duplicate: Arel.sql("openings = game_weekly_contributions.openings + 1, updated_at = excluded.updated_at"))
    end
  end
end
