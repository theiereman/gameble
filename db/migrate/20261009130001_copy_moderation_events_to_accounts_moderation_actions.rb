class CopyModerationEventsToAccountsModerationActions < ActiveRecord::Migration[8.1]
  # One INSERT ... SELECT: no schema change, no lock on the players.
  def up
    safety_assured do
      execute <<~SQL.squish
        INSERT INTO accounts_moderation_actions (kind, player_id, staff_id, reason, created_at)
        SELECT
          CASE events.event_type
            WHEN 'Accounts::PlayerBanned' THEN 'ban'
            WHEN 'Accounts::PlayerUnbanned' THEN 'unban'
            ELSE 'dismissal'
          END,
          (events.data ->> 'player_id')::bigint,
          (events.data ->> 'staff_id')::bigint,
          NULL,
          events.created_at
        FROM event_store_events events
        WHERE events.event_type IN ('Accounts::PlayerBanned', 'Accounts::PlayerUnbanned', 'Accounts::ReportsDismissed')
          AND EXISTS (SELECT 1 FROM accounts_players players WHERE players.id = (events.data ->> 'player_id')::bigint)
          AND EXISTS (SELECT 1 FROM accounts_players staff WHERE staff.id = (events.data ->> 'staff_id')::bigint)
        ORDER BY events.created_at, events.id
      SQL
    end
  end

  def down
  end
end
