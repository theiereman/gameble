module Game
  module Market
    # What a player can entrust: every unreserved copy of an edition that has a rarity, with what the Brotherhood pays for it.
    module EntrustableCopies
      Copy = Data.define(:ref, :title, :rarity, :season_number, :free, :owned, :value)

      REF_FORMAT = /\A(?<slug>[^:]+):(?<season>\d+)\z/

      SQL = <<~SQL.squish.freeze
        SELECT catalog_cards.slug, catalog_seasons.number, catalog_card_seasons.rarity,
               game_holdings.quantity - game_holdings.reserved AS free, game_holdings.quantity AS owned,
               COALESCE(localised.title, fallback.title, catalog_cards.slug) AS title
          FROM game_holdings
          JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
          JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id
          JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id
          LEFT JOIN catalog_card_texts localised ON localised.card_id = catalog_cards.id AND localised.locale = :locale
          LEFT JOIN catalog_card_texts fallback ON fallback.card_id = catalog_cards.id AND fallback.locale = 'en'
         WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > game_holdings.reserved
           AND catalog_card_seasons.rarity IS NOT NULL
      SQL

      def self.call(player, settings:, locale: I18n.locale)
        sql = Holding.sanitize_sql_array([ SQL, { player_id: player.id, locale: locale.to_s } ])
        copies = Holding.connection.select_rows(sql, "Game::Market::EntrustableCopies").map do |slug, season_number, rarity, free, owned, title|
          rarity = Catalog::Rarity::TIERS.fetch(rarity.to_i)
          Copy.new(ref: ref(slug, season_number), title:, rarity:, season_number: season_number.to_i, free: free.to_i, owned: owned.to_i, value: settings.entrustment(rarity))
        end
        copies.sort_by { [ -it.value, it.season_number, it.title, it.ref ] }
      end

      def self.ref(slug, season_number) = "#{slug}:#{season_number}"

      # Card-season ids by the refs a form submits; an unknown ref is left out.
      def self.resolve(refs)
        parsed = refs.filter_map { |ref| (match = REF_FORMAT.match(ref.to_s)) && [ ref.to_s, match[:slug], match[:season].to_i ] }
        return {} if parsed.empty?

        found = Catalog::CardSeason.joins(:card, :season)
          .where(catalog_cards: { slug: parsed.map { it[1] } }, catalog_seasons: { number: parsed.map { it[2] } })
          .pluck("catalog_cards.slug", "catalog_seasons.number", "catalog_card_seasons.id")
          .to_h { |slug, number, id| [ ref(slug, number), id ] }
        parsed.to_h { |ref, *| [ ref, found[ref] ] }.compact
      end
    end
  end
end
