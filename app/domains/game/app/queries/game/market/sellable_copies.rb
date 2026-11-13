module Game
  module Market
    # What a player can put up for sale: the editions with a free copy and a title in the locale, rarest first, then by season, title and ref.
    module SellableCopies
      Copy = Data.define(:ref, :card, :free, :reserved)

      FROM = <<~SQL.squish.freeze
          FROM game_holdings
          JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
          JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id
          JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id
          JOIN catalog_card_texts localised ON localised.card_id = catalog_cards.id AND localised.locale = :locale
          LEFT JOIN catalog_card_texts fallback ON fallback.card_id = catalog_cards.id AND fallback.locale = 'en'
         WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > game_holdings.reserved
           AND catalog_card_seasons.rarity IS NOT NULL
           AND (CAST(:card_slug AS text) IS NULL OR catalog_cards.slug = :card_slug)
      SQL

      SELECT = <<~SQL.squish.freeze
        SELECT catalog_card_seasons.id, game_holdings.quantity - game_holdings.reserved AS free, game_holdings.reserved
      SQL

      ORDER = <<~SQL.squish.freeze
        ORDER BY catalog_card_seasons.rarity DESC, catalog_seasons.number, localised.title COLLATE "C",
                 (catalog_cards.slug || ':' || catalog_seasons.number) COLLATE "C"
      SQL

      # One page of the copies the filter keeps; `refs` keeps only those editions.
      def self.call(player, locale: I18n.locale, card_slug: nil, filter: CopyFilter.none, refs: nil, offset: 0, limit: nil)
        return [] if refs&.empty?

        sql = [ SELECT, FROM, filter.conditions, (refs && "AND catalog_card_seasons.id IN (:ids)"), ORDER, (limit && "LIMIT :limit OFFSET :offset") ].compact.join(" ")
        binds = { player_id: player.id, locale: locale.to_s, card_slug:, ids: refs && EntrustableCopies.resolve(refs).values, limit:, offset:, **filter.binds }
        rows = Holding.connection.select_rows(Holding.sanitize_sql_array([ sql, binds ]), "Game::Market::SellableCopies")
        cards = Catalog::CardViews.call(rows.map { it.first.to_i }, locale:)
        rows.filter_map do |card_season_id, free, reserved|
          card = cards[card_season_id.to_i]
          Copy.new(ref: EntrustableCopies.ref(card.id, card.season_number), card:, free: free.to_i, reserved: reserved.to_i) if card
        end
      end

      def self.count(player, locale: I18n.locale, card_slug: nil, filter: CopyFilter.none)
        sql = [ "SELECT COUNT(*)", FROM, filter.conditions ].join(" ")
        binds = { player_id: player.id, locale: locale.to_s, card_slug:, **filter.binds }
        Holding.connection.select_value(Holding.sanitize_sql_array([ sql, binds ]), "Game::Market::SellableCopies").to_i
      end
    end
  end
end
