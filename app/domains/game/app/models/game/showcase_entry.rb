module Game
  class ShowcaseEntry < ApplicationRecord
    self.table_name = "game_showcase_entries"

    SIZE = 5

    RENUMBER_SQL = <<~SQL.squish.freeze
      UPDATE game_showcase_entries SET position = ranked.place, updated_at = :now
        FROM (SELECT id, ROW_NUMBER() OVER (ORDER BY position, id) - 1 AS place
                FROM game_showcase_entries WHERE player_id = :player_id) ranked
       WHERE game_showcase_entries.id = ranked.id AND game_showcase_entries.position <> ranked.place
    SQL

    def self.remove(entry)
      where(id: entry.id).delete_all
      renumber(entry.player_id)
    end

    def self.remove_unheld(player_id, card_season_ids)
      return if card_season_ids.empty?

      held = Holding.where(player_id:).where(Holding.arel_table[:quantity].gt(0)).select(:card_season_id)
      removed = where(player_id:, card_season_id: card_season_ids).where.not(card_season_id: held).delete_all
      renumber(player_id) if removed.positive?
    end

    def self.renumber(player_id)
      connection.exec_update(sanitize_sql_array([ RENUMBER_SQL, { player_id:, now: Time.current } ]), "Game::ShowcaseEntry renumber")
    end
  end
end
