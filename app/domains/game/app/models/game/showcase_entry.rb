module Game
  # One card a player chose to show on their profile, at its place among
  # the others (0 first). Written only through the operations of this pack:
  # adding, removing, moving one place and placing at a given place under
  # the player's bank lock (Game::BankLock), and a trade's removal of a card given away to the last
  # copy under the holdings' locks only, so places are renumbered from the
  # rows as they stand rather than shifted.
  class ShowcaseEntry < ApplicationRecord
    self.table_name = "game_showcase_entries"

    SIZE = 5

    RENUMBER_SQL = <<~SQL.squish.freeze
      UPDATE game_showcase_entries SET position = ranked.place, updated_at = :now
        FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY position, id) - 1 AS place
                FROM game_showcase_entries WHERE player_id = :player_id) ranked
       WHERE game_showcase_entries.id = ranked.id AND game_showcase_entries.position <> ranked.place
    SQL

    # Deletes the entry and closes the gap it leaves.
    def self.remove(entry)
      where(id: entry.id).delete_all
      renumber(entry.player_id)
    end

    # Removes the player's entries of those card-seasons they no longer hold a copy of.
    def self.remove_unheld(player_id, card_season_ids)
      return if card_season_ids.empty?

      held = Holding.where(player_id:).where(Holding.arel_table[:quantity].gt(0)).select(:card_season_id)
      removed = where(player_id:, card_season_id: card_season_ids).where.not(card_season_id: held).delete_all
      renumber(player_id) if removed.positive?
    end

    # Places the player's entries at 0..n-1, in their order (position, then id).
    def self.renumber(player_id)
      connection.exec_update(sanitize_sql_array([ RENUMBER_SQL, { player_id:, now: Time.current } ]), "Game::ShowcaseEntry renumber")
    end
  end
end
