module Game
  module Market
    module CollectionPrices
      SORTS = { "price_asc" => "ASC", "price_desc" => "DESC" }.freeze
      AMOUNT_FORMAT = /\A\d{1,13}\z/

      Choice = Data.define(:sort, :minimum, :maximum) do
        def sorted? = !sort.nil?

        def filtered? = !minimum.nil? || !maximum.nil?

        def active? = sorted? || filtered?

        def count = (sorted? ? 1 : 0) + [ minimum, maximum ].compact.size

        def params = { sort:, min_price: minimum, max_price: maximum }.compact
      end

      NONE = Choice.new(sort: nil, minimum: nil, maximum: nil)

      PRICE = <<~SQL.squish.freeze
        LEFT JOIN LATERAL (
          SELECT edition_prices.average, edition_prices.sales_used
            FROM (
              SELECT game_holdings.card_season_id
                FROM game_holdings
                JOIN catalog_card_seasons held_seasons ON held_seasons.id = game_holdings.card_season_id
               WHERE game_holdings.player_id = CAST(:owner_id AS bigint) AND game_holdings.quantity > 0
                 AND held_seasons.card_id = catalog_card_seasons.card_id
              UNION ALL
              SELECT catalog_card_seasons.id
               WHERE NOT EXISTS (
                 SELECT 1 FROM game_holdings
                   JOIN catalog_card_seasons held_seasons ON held_seasons.id = game_holdings.card_season_id
                  WHERE game_holdings.player_id = CAST(:owner_id AS bigint) AND game_holdings.quantity > 0
                    AND held_seasons.card_id = catalog_card_seasons.card_id)
            ) candidates
            LEFT JOIN game_market_edition_prices edition_prices ON edition_prices.card_season_id = candidates.card_season_id
           ORDER BY edition_prices.average DESC NULLS LAST, candidates.card_season_id
           LIMIT 1
        ) card_price ON TRUE
      SQL

      def self.choice(sort:, minimum:, maximum:, state: MarketState.call)
        return NONE unless state.first_opened?

        Choice.new(sort: (sort if SORTS.key?(sort)), minimum: amount(minimum), maximum: amount(maximum))
      end

      def self.apply(relation, choice, owner:)
        return relation unless choice.active?

        relation = relation.joins(Holding.sanitize_sql_array([ PRICE, { owner_id: owner&.id } ]))
        relation = relation.where("card_price.average >= ?", choice.minimum) if choice.minimum
        relation = relation.where("card_price.average <= ?", choice.maximum) if choice.maximum
        return relation unless choice.sorted?

        relation.reorder(Arel.sql("card_price.average IS NULL"), Arel.sql("card_price.average #{SORTS.fetch(choice.sort)}"), :number, :id)
      end

      def self.for_cards(tiles, owner:)
        return {} if tiles.empty?

        sql = Holding.sanitize_sql_array([ "SELECT catalog_card_seasons.card_id, card_price.average, card_price.sales_used " \
          "FROM catalog_card_seasons #{PRICE} WHERE catalog_card_seasons.id IN (:ids)", { owner_id: owner&.id, ids: tiles.map(&:first) }])
        Holding.connection.select_rows(sql, "Game::Market::CollectionPrices").to_h do |card_id, average, sales_used|
          [ card_id.to_i, EditionPrices::Price.new(average: average&.to_i, sales_used: sales_used.to_i) ]
        end
      end

      def self.amount(value) = (Integer(value, 10) if value.is_a?(String) && value.strip.match?(AMOUNT_FORMAT))
      private_class_method :amount
    end
  end
end
