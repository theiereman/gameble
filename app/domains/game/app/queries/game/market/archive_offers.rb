module Game
  module Market
    # The week's list of the Archives, the same for every player, each edition at the week's price of its rarity (ArchivePrices) while copies
    # are left. Epics and Legendaries leave the Archives by auction instead.
    module ArchiveOffers
      PER_PAGE = 24
      DEFAULT_SORT = "price_asc".freeze
      SORTS = { "price_asc" => "ASC", "price_desc" => "DESC" }.freeze
      LISTED = %i[common uncommon rare].freeze
      WANTED_PLACES = 10
      RARE_PLACES = 10
      # WANTED stands for the players who want cards, filled in once bound.
      LIST_SQL = <<~SQL.squish.freeze
        WITH pool AS (
          SELECT picked.id AS card_season_id, picked.rarity, md5(picked.id::text || :seed) AS shuffle,
            (SELECT COUNT(DISTINCT wanted.player_id) FROM (WANTED) wanted
              WHERE wanted.card_id = picked.card_id AND (wanted.reason = 'goal' OR picked.rarity = ANY(wanted.rarities))) AS seekers
          FROM catalog_card_seasons picked
          WHERE picked.rarity IN (:tiers) AND picked.id IN (
            SELECT card_season_id FROM game_market_archive_stocks
            UNION SELECT card_season_id FROM game_market_archive_withdrawals WHERE created_at >= :week)
        ), most_wanted AS (
          SELECT card_season_id FROM pool WHERE seekers > 0 ORDER BY seekers DESC, shuffle LIMIT :wanted
        ), rares AS (
          SELECT card_season_id FROM pool WHERE rarity = :rare AND card_season_id NOT IN (SELECT card_season_id FROM most_wanted)
          ORDER BY shuffle LIMIT :rares
        )
        SELECT pool.card_season_id FROM pool
        LEFT JOIN most_wanted ON most_wanted.card_season_id = pool.card_season_id
        LEFT JOIN rares ON rares.card_season_id = pool.card_season_id
        WHERE most_wanted.card_season_id IS NOT NULL OR rares.card_season_id IS NOT NULL OR pool.rarity < :rare
        ORDER BY most_wanted.card_season_id IS NULL, rares.card_season_id IS NULL, pool.seekers DESC, pool.rarity DESC, pool.shuffle
        LIMIT :size
      SQL

      Row = Data.define(:card, :price, :stock)
      Page = Data.define(:rows, :more)
      Counts = Data.define(:cards, :editions)

      def self.call(settings:, sort:, page:, locale:, filters: ListingFilters.none)
        direction = SORTS.fetch(sort, SORTS.fetch(DEFAULT_SORT))
        page = [ page.to_i, 1 ].max
        found = offers(settings, filters, locale)
          .order(Arel.sql("#{price_sql(settings)} #{direction}, game_market_archive_stocks.card_season_id ASC"))
          .offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1)
          .pluck(*columns(settings))
        Page.new(rows: build(found.first(PER_PAGE), locale:), more: found.size > PER_PAGE)
      end

      def self.count(settings:, locale:, filters: ListingFilters.none)
        cards, editions = offers(settings, filters, locale).pick(Arel.sql("COUNT(DISTINCT catalog_card_seasons.card_id)"), Arel.sql("COUNT(*)"))
        Counts.new(cards:, editions:)
      end

      # The one edition, or nil when the Archives do not sell it now.
      def self.find(settings:, card_season_id:, locale:)
        found = offers(settings, ListingFilters.none, locale).where(card_season_id:).pluck(*columns(settings))
        build(found, locale:).first
      end

      def self.bought_this_week?(player:, card_season_id:)
        ArchiveWithdrawal.where(player_id: player.id, card_season_id:).where(created_at: ArchivePrices.week_start..).exists?
      end

      def self.listed?(settings:, card_season_id:)
        offers(settings, ListingFilters.none, I18n.locale).exists?(card_season_id:)
      end

      # The panel's offers: the viewer's wanted cards first, then the latest entrusted.
      def self.featured(settings:, wanted_card_ids:, locale:, limit: 4)
        wanted = wanted_card_ids.any? ? ArchiveStock.sanitize_sql_array([ "catalog_card_seasons.card_id IN (?)", wanted_card_ids ]) : "FALSE"
        found = offers(settings, ListingFilters.none, locale)
          .order(Arel.sql("CASE WHEN #{wanted} THEN 0 ELSE 1 END, #{entrusted_day_sql} DESC NULLS LAST, game_market_archive_stocks.card_season_id ASC"))
          .limit(limit).pluck(*columns(settings))
        build(found, locale:)
      end

      def self.for_card(settings:, card_id:, locale:)
        found = offers(settings, ListingFilters.none, locale).where(catalog_card_seasons: { card_id: })
          .order(Arel.sql("#{price_sql(settings)} ASC, game_market_archive_stocks.card_season_id ASC")).pluck(*columns(settings))
        build(found, locale:)
      end

      def self.listed_rarities = LISTED.map(&:to_s)

      def self.listed_tiers = Catalog::Rarity::TIERS.select { |_tier, rarity| LISTED.include?(rarity) }

      # The editions of the week, drawn once a week from those held then or sold since Monday: the most wanted first, then Rares, then
      # Uncommons and Commons, in a shuffle fixed for the week.
      def self.list(settings, now: Time.current)
        week = ArchivePrices.week_start(now)
        Rails.cache.fetch([ "archive-list", week.to_i, settings.archive_list_size ], expires_in: 1.week) do
          binds = { tiers: listed_tiers.keys, rare: listed_tiers.key(:rare), week:, seed: week.to_date.iso8601, wanted: WANTED_PLACES,
            rares: RARE_PLACES, size: settings.archive_list_size }
          ArchiveStock.connection.select_values(ArchiveStock.sanitize_sql_array([ LIST_SQL, binds ]).sub("WANTED", Wanted.in_play.to_sql))
        end
      end

      # The week's list in stock under the filters; price bounds apply to the week's price, and hiding one's own sales leaves offers in.
      def self.offers(settings, filters, locale)
        stocks = ArchiveStock.joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_market_archive_stocks.card_season_id")
          .where(card_season_id: list(settings))
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

      def self.price_sql(settings) = rarity_case(settings, ArchivePrices.call(settings))

      def self.rarity_case(settings, prices)
        branches = listed_tiers.map { |tier, rarity| "WHEN #{tier} THEN #{Integer(prices.fetch(rarity))}" }
        "CASE catalog_card_seasons.rarity #{branches.join(" ")} END"
      end

      def self.build(found, locale:)
        cards = Catalog::CardViews.call(found.map(&:first), locale:)
        found.filter_map do |card_season_id, stock, price|
          card = cards[card_season_id]
          Row.new(card:, price:, stock:) if card
        end
      end

      private_class_method :listed_tiers, :columns, :build, :rarity_case
    end
  end
end
