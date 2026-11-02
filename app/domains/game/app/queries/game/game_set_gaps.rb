module Game
  module GameSetGaps
    HELD = <<~SQL.squish.freeze
      SELECT DISTINCT game_holdings.player_id, catalog_card_seasons.card_id
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
       WHERE game_holdings.player_id IN (:player_ids) AND game_holdings.quantity > 0
         AND catalog_card_seasons.card_id IN (:card_ids)
    SQL

    def self.call(player_ids)
      return {} if player_ids.empty?

      rows = Goal.where(player_id: player_ids, custom_set_id: nil).pluck(:player_id, :position, :set_kind, :set_key)
      return {} if rows.empty?

      albums = Catalog::SetsByKey.call(season: Catalog::PublishedSeason.call, keys: rows.map { |_id, _position, kind, key| [ kind, key ] })
      held = held_games(player_ids.uniq, albums.values.flat_map(&:card_ids).uniq)
      rows.each_with_object({}) do |(player_id, position, kind, key), gaps|
        album = albums[[ kind, key ]] or next
        owned = held.fetch(player_id, Set.new)
        album.card_ids.each { |card_id| ((gaps[player_id] ||= {})[card_id] ||= []) << position unless owned.include?(card_id) }
      end
    end

    def self.held_games(player_ids, card_ids)
      return {} if card_ids.empty?

      sql = Holding.sanitize_sql_array([ HELD, { player_ids:, card_ids: } ])
      Holding.connection.select_rows(sql, "Game::GameSetGaps.held_games")
        .each_with_object({}) { |(player_id, card_id), held| (held[player_id.to_i] ||= Set.new) << card_id.to_i }
    end

    private_class_method :held_games
  end
end
