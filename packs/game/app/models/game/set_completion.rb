module Game
  # A set a player completed (CAP-6, AD-9, AD-10, story 6.7): one row per
  # player and set, unique in the database, inserted the first time the
  # player holds every card of the set. Its insert decides that
  # Game::SetCompleted is published, once; a card traded away and gained
  # again completes nothing new.
  class SetCompletion < ApplicationRecord
    self.table_name = "game_set_completions"

    # The sets holding one of the cards, not completed by the player yet,
    # whose every card-season the player holds with copies left (AD-2: Game
    # reads Catalog's memberships). One statement, whatever the sets.
    RECORD_SQL = <<~SQL.squish.freeze
      INSERT INTO game_set_completions (player_id, set_id, completed_at, created_at, updated_at)
      SELECT :player_id, members.set_id, :now, :now, :now
        FROM catalog_set_memberships AS members
        LEFT JOIN game_holdings
          ON game_holdings.player_id = :player_id
         AND game_holdings.card_season_id = members.card_season_id
         AND game_holdings.quantity > 0
       WHERE members.set_id IN (SELECT set_id FROM catalog_set_memberships WHERE card_season_id IN (:card_season_ids))
         AND NOT EXISTS (SELECT 1 FROM game_set_completions AS done
                          WHERE done.player_id = :player_id AND done.set_id = members.set_id)
       GROUP BY members.set_id
      HAVING COUNT(game_holdings.id) = COUNT(*)
       ORDER BY members.set_id
          ON CONFLICT (player_id, set_id) DO NOTHING
      RETURNING set_id
    SQL

    # Records the sets the player completes with `card_season_ids`, the
    # cards an operation has just credited to them, in its transaction:
    # answers the ids of the sets completed for the first time, ascending.
    def self.record(player_id, card_season_ids, now)
      return [] if card_season_ids.empty?

      sql = sanitize_sql_array([ RECORD_SQL, { player_id:, card_season_ids: card_season_ids.uniq, now: } ])
      connection.select_values(sql, "Game::SetCompletion Record").map(&:to_i).sort
    end
  end
end
