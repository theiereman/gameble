module Game
  # A player's contribution to the weekly goal: one row per player and week,
  # unique in the database. `openings` counts the packs the player opened that
  # week, `trades` the trades credited to them; the goal's total sums both.
  # Written only by the handlers of Game::PackOpened and Game::TradeAccepted,
  # in their operation's transaction.
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

    def self.record_trade(proposer_id, recipient_id, now)
      stamp = now.utc
      week_start = WeeklyGoal.week_start(stamp)
      credited = recipient_id
      rows = [ proposer_id, recipient_id ].sort.map do |player_id|
        { player_id:, week_start:, openings: 0, trades: player_id == credited ? 1 : 0, created_at: stamp, updated_at: stamp }
      end
      upsert_all(rows, unique_by: %i[player_id week_start], record_timestamps: false,
        on_duplicate: Arel.sql("trades = game_weekly_contributions.trades + excluded.trades, updated_at = excluded.updated_at"))
    end
  end
end
