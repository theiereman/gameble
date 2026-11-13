module Game
  module Market
    # What a player can entrust: every unreserved copy of an edition that has a rarity, with what the Brotherhood pays for it,
    # most valuable first, then by season, title and ref.
    module EntrustableCopies
      Copy = Data.define(:ref, :title, :rarity, :season_number, :free, :owned, :value, :card)

      REF_FORMAT = /\A(?<slug>[^:]+):(?<season>\d+)\z/

      FROM = <<~SQL.squish.freeze
          FROM game_holdings
          JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
          JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id
          JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id
          LEFT JOIN catalog_card_texts localised ON localised.card_id = catalog_cards.id AND localised.locale = :locale
          LEFT JOIN catalog_card_texts fallback ON fallback.card_id = catalog_cards.id AND fallback.locale = 'en'
         WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > game_holdings.reserved
           AND catalog_card_seasons.rarity IS NOT NULL
           AND (CAST(:card_slug AS text) IS NULL OR catalog_cards.slug = :card_slug)
      SQL

      COLUMNS = <<~SQL.squish.freeze
        SELECT catalog_card_seasons.id, catalog_cards.slug, catalog_seasons.number, catalog_card_seasons.rarity,
               game_holdings.quantity - game_holdings.reserved AS free, game_holdings.quantity AS owned,
               COALESCE(localised.title, fallback.title, catalog_cards.slug) AS title
      SQL

      ORDER = <<~SQL.squish.freeze
        ORDER BY %<value>s DESC, catalog_seasons.number, COALESCE(localised.title, fallback.title, catalog_cards.slug) COLLATE "C",
                 (catalog_cards.slug || ':' || catalog_seasons.number) COLLATE "C"
      SQL

      # One page of the copies the filter keeps, with the card to draw when `cards` is set; `refs` keeps only those editions.
      def self.call(player, settings:, locale: I18n.locale, card_slug: nil, filter: CopyFilter.none, refs: nil, offset: 0, limit: nil, cards: true)
        return [] if refs&.empty?

        sql = [ COLUMNS, FROM, filter.conditions, (refs && "AND catalog_card_seasons.id IN (:ids)"), format(ORDER, value: value_sql(settings)),
          (limit && "LIMIT :limit OFFSET :offset") ].compact.join(" ")
        binds = { player_id: player.id, locale: locale.to_s, card_slug:, ids: refs && resolve(refs).values, limit:, offset:, **filter.binds }
        rows = Holding.connection.select_rows(Holding.sanitize_sql_array([ sql, binds ]), "Game::Market::EntrustableCopies")
        views = cards ? Catalog::CardViews.call(rows.map { it.first.to_i }, locale:) : {}
        rows.map { |row| copy(row, settings, views) }
      end

      def self.count(player, locale: I18n.locale, card_slug: nil, filter: CopyFilter.none)
        sql = [ "SELECT COUNT(*)", FROM, filter.conditions ].join(" ")
        binds = { player_id: player.id, locale: locale.to_s, card_slug:, **filter.binds }
        Holding.connection.select_value(Holding.sanitize_sql_array([ sql, binds ]), "Game::Market::EntrustableCopies").to_i
      end

      def self.copy((card_season_id, slug, season_number, rarity, free, owned, title), settings, views)
        rarity = Catalog::Rarity::TIERS.fetch(rarity.to_i)
        Copy.new(ref: ref(slug, season_number), title:, rarity:, season_number: season_number.to_i, free: free.to_i, owned: owned.to_i,
          value: settings.entrustment(rarity), card: views[card_season_id.to_i])
      end
      private_class_method :copy

      def self.value_sql(settings)
        branches = Catalog::Rarity::TIERS.map { |tier, rarity| "WHEN #{tier} THEN #{Integer(settings.entrustment(rarity))}" }
        "CASE catalog_card_seasons.rarity #{branches.join(" ")} END"
      end
      private_class_method :value_sql

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
