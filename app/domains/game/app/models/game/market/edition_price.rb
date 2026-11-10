module Game
  module Market
    # The average price of one card-season's recent sales. The formula lives here and nowhere else; only the settlement writes the row.
    class EditionPrice < ApplicationRecord
      self.table_name = "game_market_edition_prices"

      MINIMUM_SALES = 3

      belongs_to :card_season, class_name: "Catalog::CardSeason"

      def self.average_of(prices)
        return if prices.empty?

        kept = prices.size >= MINIMUM_SALES ? prices.sort[1...-1] : prices
        kept.sum.div(kept.size)
      end

      def self.sales_in_window(card_season_id, settings:, now:)
        Listing.sold.where(card_season_id:).where("sold_at > ?", now - settings.average_window_days.days)
          .order(sold_at: :desc, id: :desc).limit(settings.average_sale_count).pluck(:final_price)
      end

      def self.lock_row(card_season_id)
        insert_all([ { card_season_id: } ], unique_by: :card_season_id)
        lock.find_by!(card_season_id:)
      end
    end
  end
end
