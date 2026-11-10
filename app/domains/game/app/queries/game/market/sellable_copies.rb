module Game
  module Market
    # What a player can put up for sale: one row per edition holding a free copy and a rarity, with the card to draw.
    module SellableCopies
      Copy = Data.define(:ref, :card, :free, :reserved)

      SQL = <<~SQL.squish.freeze
        SELECT catalog_card_seasons.id, catalog_cards.slug, catalog_seasons.number,
               game_holdings.quantity - game_holdings.reserved AS free, game_holdings.reserved
          FROM game_holdings
          JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
          JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id
          JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id
         WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > game_holdings.reserved
           AND catalog_card_seasons.rarity IS NOT NULL
           AND (CAST(:card_slug AS text) IS NULL OR catalog_cards.slug = :card_slug)
      SQL

      def self.call(player, locale: I18n.locale, card_slug: nil)
        sql = Holding.sanitize_sql_array([ SQL, { player_id: player.id, card_slug: } ])
        rows = Holding.connection.select_rows(sql, "Game::Market::SellableCopies")
        cards = Catalog::CardViews.call(rows.map { it.first.to_i }, locale:)
        copies = rows.filter_map do |card_season_id, slug, season_number, free, reserved|
          card = cards[card_season_id.to_i]
          Copy.new(ref: EntrustableCopies.ref(slug, season_number), card:, free: free.to_i, reserved: reserved.to_i) if card
        end
        copies.sort_by { [ -tier(it.card.rarity), it.card.season_number, it.card.title, it.ref ] }
      end

      def self.tier(rarity) = Catalog::Rarity::TIERS.key(rarity.to_sym)
    end
  end
end
