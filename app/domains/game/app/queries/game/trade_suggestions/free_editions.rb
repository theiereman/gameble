module Game
  module TradeSuggestions
    module FreeEditions
      Edition = Data.define(:card_season_id, :free, :rarity, :season_number, :slug)

      SQL = <<~SQL.squish.freeze
        SELECT game_holdings.player_id, catalog_card_seasons.card_id, game_holdings.card_season_id,
               game_holdings.quantity - game_holdings.reserved AS free, COALESCE(catalog_card_seasons.rarity, 0) AS rarity,
               catalog_seasons.number, catalog_cards.slug
          FROM game_holdings
          JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
          JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id
          JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id
         WHERE game_holdings.player_id IN (:player_ids) AND game_holdings.quantity > game_holdings.reserved
           AND (:all_cards OR catalog_card_seasons.card_id IN (:card_ids))
      SQL

      CARDS_OF_SEASONS = "SELECT id, card_id FROM catalog_card_seasons WHERE id IN (:card_season_ids)".freeze

      def self.call(player_ids, card_ids)
        sql = Holding.sanitize_sql_array([ SQL, { player_ids:, card_ids: card_ids || [ 0 ], all_cards: card_ids.nil? } ])
        Holding.connection.select_rows(sql, "Game::TradeSuggestions::FreeEditions")
          .group_by { |player_id, card_id| [ player_id.to_i, card_id.to_i ] }
          .transform_values do |rows|
            rows.map do |_, _, card_season_id, free, rarity, season_number, slug|
              Edition.new(card_season_id: card_season_id.to_i, free: free.to_i, rarity: rarity.to_i, season_number: season_number.to_i, slug:)
            end
          end
      end

      def self.card_ids_of(card_season_ids)
        sql = Holding.sanitize_sql_array([ CARDS_OF_SEASONS, { card_season_ids: } ])
        Holding.connection.select_rows(sql, "Game::TradeSuggestions::FreeEditions.card_ids_of").to_h { |id, card_id| [ id.to_i, card_id.to_i ] }
      end

      def self.spare(editions) = editions.select { it.free.positive? }

      def self.placed(editions) = spare(editions).max_by { [ it.free, -it.season_number ] }

      def self.copies(editions) = editions.sum(&:free)
    end
  end
end
