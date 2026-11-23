module Game
  module Market
    class EditionPrice < ApplicationRecord
      self.table_name = "game_market_edition_prices"

      MINIMUM_SALES = 3

      SALES = <<~SQL.squish.freeze
        SELECT card_season_id, sold_at, final_price, average_after_sale, 0 AS source, id, seller_id, leader_id, settings_id
          FROM game_market_listings WHERE status = 'sold'
        UNION ALL
        SELECT served_card_season_id, served_at, price, average_after_sale, 1, id, seller_id, player_id, settings_id
          FROM game_market_orders WHERE status = 'served'
      SQL
      NEWEST_FIRST = { sold_at: :desc, source: :desc, id: :desc }.freeze

      belongs_to :card_season, class_name: "Catalog::CardSeason"

      def self.average_of(prices)
        return if prices.empty?

        kept = prices.size >= MINIMUM_SALES ? prices.sort[1...-1] : prices
        kept.sum.div(kept.size)
      end

      # Every sale of every edition, sold listings and served orders alike, with a listing's column names.
      def self.sales = Listing.from("(#{SALES}) AS #{Listing.quoted_table_name}")

      def self.rarity_average(rarity, settings:, now:)
        Median.of(sales.where(card_season_id: Catalog::CardSeason.where(rarity:).select(:id))
          .where(sold_at: (now - settings.average_window_days.days)...now).pluck(:final_price))
      end

      def self.sales_in_window(card_season_id, settings:, now:)
        sales.where(card_season_id:).where("sold_at > ?", now - settings.average_window_days.days)
          .order(NEWEST_FIRST).limit(settings.average_sale_count).pluck(:final_price)
      end

      def self.lock_row(card_season_id)
        insert_all([ { card_season_id: } ], unique_by: :card_season_id)
        lock.find_by!(card_season_id:)
      end
    end
  end
end
