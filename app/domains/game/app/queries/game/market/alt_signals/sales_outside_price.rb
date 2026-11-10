module Game
  module Market
    module AltSignals
      module SalesOutsidePrice
        OUTSIDE = <<~SQL.squish.freeze
          SELECT seller_id, leader_id, CASE WHEN final_price < reference THEN 1 ELSE 0 END
          FROM (
            SELECT seller_id, leader_id, final_price, sold_at,
              LAG(average_after_sale) OVER (PARTITION BY card_season_id ORDER BY sold_at, id) AS reference,
              COUNT(*) OVER (PARTITION BY card_season_id ORDER BY sold_at, id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS earlier_sales
            FROM game_market_listings
            WHERE status = 'sold'
          ) sales
          WHERE sold_at >= :since AND leader_id IS NOT NULL AND earlier_sales >= :few_sales AND reference > 0
            AND (final_price * :ratio < reference OR final_price > reference * :ratio)
        SQL

        def self.call(now:)
          sql = Listing.sanitize_sql_array([ OUTSIDE, { since: now - MARKET_WINDOW_DAYS.days, few_sales: EditionPrice::MINIMUM_SALES, ratio: OUTSIDE_PRICE_RATIO } ])
          sales = Listing.connection.select_rows(sql).map { |seller_id, buyer_id, below| [ [ seller_id, buyer_id ], below.to_i ] }
          sales.group_by(&:first).filter_map { |pair, group| detected(pair, group.map(&:last)) }
        end

        def self.detected(pair, below_flags)
          return if below_flags.size < OUTSIDE_PRICE_SALES_REQUIRED

          below = below_flags.sum
          Detected.new(account_id: pair.first, signal: "sales_outside_price", other_account_id: pair.last,
            facts: { "sales" => below_flags.size, "below" => below, "above" => below_flags.size - below })
        end

        private_class_method :detected
      end
    end
  end
end
