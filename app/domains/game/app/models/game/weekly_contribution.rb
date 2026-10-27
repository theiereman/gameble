module Game
  class WeeklyContribution < ApplicationRecord
    self.table_name = "game_weekly_contributions"

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
