class GrantCapacitySlotsAlreadyUsed < ActiveRecord::Migration[8.1]
  FREE_CUSTOM_SETS = 5
  FREE_DECKS = 3

  def up
    safety_assured do
      execute <<~SQL.squish
        INSERT INTO game_capacity_slots (player_id, kind, bought, created_at, updated_at)
        SELECT player_id, 'custom_set', count(*) - #{FREE_CUSTOM_SETS}, now(), now()
        FROM game_custom_sets WHERE kind = 'custom'
        GROUP BY player_id HAVING count(*) > #{FREE_CUSTOM_SETS}
        UNION ALL
        SELECT player_id, 'deck', count(*) - #{FREE_DECKS}, now(), now()
        FROM game_decks
        GROUP BY player_id HAVING count(*) > #{FREE_DECKS}
        ON CONFLICT (player_id, kind) DO NOTHING
      SQL
    end
  end

  def down
  end
end
