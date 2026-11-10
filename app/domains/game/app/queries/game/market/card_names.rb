module Game
  module Market
    # The title and season number of card-seasons, whether or not the player still holds them free.
    module CardNames
      Name = Data.define(:title, :season_number)

      SQL = <<~SQL.squish.freeze
        SELECT catalog_card_seasons.id, catalog_seasons.number,
               COALESCE(localised.title, fallback.title, catalog_cards.slug) AS title
          FROM catalog_card_seasons
          JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id
          JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id
          LEFT JOIN catalog_card_texts localised ON localised.card_id = catalog_cards.id AND localised.locale = :locale
          LEFT JOIN catalog_card_texts fallback ON fallback.card_id = catalog_cards.id AND fallback.locale = 'en'
         WHERE catalog_card_seasons.id IN (:ids)
      SQL

      def self.call(card_season_ids, locale: I18n.locale)
        return {} if card_season_ids.empty?

        sql = Holding.sanitize_sql_array([ SQL, { ids: card_season_ids.to_a, locale: locale.to_s } ])
        Holding.connection.select_rows(sql, "Game::Market::CardNames").to_h { |id, number, title| [ id.to_i, Name.new(title:, season_number: number.to_i) ] }
      end
    end
  end
end
