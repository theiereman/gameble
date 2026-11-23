module Game
  module Market
    # The editions the Archives hold, each at the Archive price of its rarity in the given version; a rarity without a price is left out.
    module ArchiveOffers
      PER_PAGE = 24
      DEFAULT_SORT = "price_asc".freeze
      SORTS = { "price_asc" => "ASC", "price_desc" => "DESC" }.freeze

      Row = Data.define(:card, :price, :stock)
      Page = Data.define(:rows, :more)
      Counts = Data.define(:cards, :editions)

      def self.call(settings:, sort:, page:, locale:, filters: ListingFilters.none)
        return Page.new(rows: [], more: false) if priced_tiers(settings).empty?

        direction = SORTS.fetch(sort, SORTS.fetch(DEFAULT_SORT))
        page = [ page.to_i, 1 ].max
        found = offers(settings, filters, locale)
          .order(Arel.sql("#{price_sql(settings)} #{direction}, game_market_archive_stocks.card_season_id ASC"))
          .offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1)
          .pluck(*columns(settings))
        Page.new(rows: build(found.first(PER_PAGE), locale:), more: found.size > PER_PAGE)
      end

      def self.count(settings:, locale:, filters: ListingFilters.none)
        return Counts.new(cards: 0, editions: 0) if priced_tiers(settings).empty?

        cards, editions = offers(settings, filters, locale).pick(Arel.sql("COUNT(DISTINCT catalog_card_seasons.card_id)"), Arel.sql("COUNT(*)"))
        Counts.new(cards:, editions:)
      end

      # The one edition, or nil when the Archives do not sell it now.
      def self.find(settings:, card_season_id:, locale:)
        return if priced_tiers(settings).empty?

        found = offers(settings, ListingFilters.none, locale).where(card_season_id:).pluck(*columns(settings))
        build(found, locale:).first
      end

      # The panel's offers: the viewer's wanted cards first, then the latest entrusted.
      def self.featured(settings:, wanted_card_ids:, locale:, limit: 4)
        return [] if priced_tiers(settings).empty?

        wanted = wanted_card_ids.any? ? ArchiveStock.sanitize_sql_array([ "catalog_card_seasons.card_id IN (?)", wanted_card_ids ]) : "FALSE"
        found = offers(settings, ListingFilters.none, locale)
          .order(Arel.sql("CASE WHEN #{wanted} THEN 0 ELSE 1 END, #{entrusted_day_sql} DESC NULLS LAST, game_market_archive_stocks.card_season_id ASC"))
          .limit(limit).pluck(*columns(settings))
        build(found, locale:)
      end

      def self.for_card(settings:, card_id:, locale:)
        return [] if priced_tiers(settings).empty?

        found = offers(settings, ListingFilters.none, locale).where(catalog_card_seasons: { card_id: })
          .order(Arel.sql("#{price_sql(settings)} ASC, game_market_archive_stocks.card_season_id ASC")).pluck(*columns(settings))
        build(found, locale:)
      end

      def self.priced_rarities(settings) = SettingsRules::RARITIES.select { settings.archive_price(it) }.map(&:to_s)

      def self.priced_tiers(settings) = Catalog::Rarity::TIERS.select { |_tier, rarity| settings.archive_price(rarity) }

      # The priced stock under the filters; price bounds apply to the fixed price, and hiding one's own sales leaves offers in.
      def self.offers(settings, filters, locale)
        stocks = ArchiveStock.joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_market_archive_stocks.card_season_id")
          .where("catalog_card_seasons.rarity IN (?)", priced_tiers(settings).keys)
        stocks = stocks.where("#{price_sql(settings)} >= ?", filters.min_price) if filters.min_price
        stocks = stocks.where("#{price_sql(settings)} <= ?", filters.max_price) if filters.max_price
        filters.with(min_price: nil, max_price: nil, hidden_seller: nil).apply(stocks, locale:)
      end

      def self.entrusted_day_sql
        "(SELECT date_trunc('day', MAX(d.updated_at)) FROM game_market_archive_deposits d " \
          "WHERE d.card_season_id = game_market_archive_stocks.card_season_id)"
      end

      def self.columns(settings)
        [ "game_market_archive_stocks.card_season_id", "game_market_archive_stocks.quantity", price_sql(settings) ].map { Arel.sql(it) }
      end

      def self.price_sql(settings)
        branches = priced_tiers(settings).map { |tier, rarity| "WHEN #{tier} THEN #{Integer(settings.archive_price(rarity))}" }
        "CASE catalog_card_seasons.rarity #{branches.join(" ")} END"
      end

      def self.build(found, locale:)
        cards = Catalog::CardViews.call(found.map(&:first), locale:)
        found.filter_map do |card_season_id, stock, price|
          card = cards[card_season_id]
          Row.new(card:, price:, stock:) if card
        end
      end

      private_class_method :priced_tiers, :columns, :build
    end
  end
end
