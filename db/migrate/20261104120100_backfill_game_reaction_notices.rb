# The reactions given before the notices existed count as their reactors' first, so that changing or withdrawing one tells no one.
class BackfillGameReactionNotices < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute <<~SQL.squish
        INSERT INTO game_reaction_notices (feed_entry_id, reactor_id, created_at, updated_at)
        SELECT reactions.feed_entry_id, reactions.player_id, reactions.created_at, reactions.created_at
          FROM game_feed_reactions AS reactions
          JOIN game_feed_entries AS entries ON entries.id = reactions.feed_entry_id
         WHERE reactions.player_id <> entries.player_id
           AND reactions.player_id IS DISTINCT FROM entries.partner_id
        ON CONFLICT (feed_entry_id, reactor_id) DO NOTHING
      SQL
    end
  end

  def down
  end
end
