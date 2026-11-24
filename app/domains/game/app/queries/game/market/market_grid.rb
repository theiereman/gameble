module Game
  module Market
    # The listings grid: open listings and the Archives' priced stock in one order, so every page continues the one before.
    module MarketGrid
      PER_PAGE = 24
      LISTING = 0
      OFFER = 1
      ORDERS = {
        "ending" => "kind ASC, ends_at ASC, price ASC, id ASC",
        "price_asc" => "price ASC, kind ASC, id ASC",
        "price_desc" => "price DESC, kind ASC, id ASC",
        "newest" => "listed_at DESC NULLS LAST, kind ASC, id DESC"
      }.freeze

      def self.call(settings:, sort:, page:, locale:, filters: ListingFilters.none)
        return OpenListings.call(sort:, page:, locale:, filters:) unless priced?(settings)

        page = [ page.to_i, 1 ].max
        found = Listing.from("(#{listings_sql(filters, locale)} UNION ALL #{offers_sql(settings, filters, locale)}) AS game_market_listings")
          .order(Arel.sql(ORDERS.fetch(sort, ORDERS.fetch(OpenListings::DEFAULT_SORT))))
          .offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1)
          .pluck(:kind, :id, :token, :card_season_id, :price, :ends_at, :stock)
        OpenListings::Page.new(rows: build(found.first(PER_PAGE), locale:), more: found.size > PER_PAGE)
      end

      def self.offers_count(settings:, locale:, filters: ListingFilters.none)
        priced?(settings) ? ArchiveOffers.count(settings:, locale:, filters:).editions : 0
      end

      def self.priced?(settings) = settings.present?

      def self.listings_sql(filters, locale)
        filters.apply(Listing.open_now, locale:).select(
          "#{LISTING} AS kind", "game_market_listings.id", "game_market_listings.token", "game_market_listings.card_season_id",
          "game_market_listings.current_price AS price", "game_market_listings.ends_at",
          "game_market_listings.created_at AS listed_at", "NULL::integer AS stock"
        ).to_sql
      end

      def self.offers_sql(settings, filters, locale)
        ArchiveOffers.offers(settings, filters, locale).select(
          "#{OFFER} AS kind", "game_market_archive_stocks.card_season_id AS id", "NULL::varchar AS token", "game_market_archive_stocks.card_season_id",
          "#{ArchiveOffers.price_sql(settings)} AS price", "NULL::timestamp AS ends_at",
          "#{ArchiveOffers.entrusted_day_sql} AS listed_at", "game_market_archive_stocks.quantity AS stock"
        ).to_sql
      end

      def self.build(found, locale:)
        listings = OpenListings.build(found.select { it.first == LISTING }.map { it[1, 5] }, locale:).index_by(&:token)
        cards = Catalog::CardViews.call(found.filter_map { it[3] if it.first == OFFER }, locale:)
        found.filter_map do |kind, _id, token, card_season_id, price, _ends_at, stock|
          next listings[token] if kind == LISTING

          card = cards[card_season_id]
          ArchiveOffers::Row.new(card:, price:, stock:) if card
        end
      end

      private_class_method :priced?, :listings_sql, :offers_sql, :build
    end
  end
end
