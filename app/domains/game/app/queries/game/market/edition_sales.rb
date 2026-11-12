module Game
  module Market
    module EditionSales
      Sale = Data.define(:sold_at, :final_price, :average_after_sale)

      Chart = Data.define(:sales, :floor, :rarity, :window_days) do
        def count = sales.size

        def averaged? = count >= EditionPrice::MINIMUM_SALES

        def last_sale = sales.last

        def last_average = (sales.filter_map(&:average_after_sale).last if averaged?)
      end

      Fingerprint = Data.define(:sales_used, :refreshed_at)

      def self.call(card_season_id, now: Time.current, settings: CurrentSettings.call)
        rarity = Catalog::CardSeason.where(id: card_season_id).pick(:rarity).to_sym
        sales = Listing.sold.where(card_season_id:).where("sold_at > ?", now - settings.average_window_days.days)
          .order(sold_at: :desc, id: :desc).limit(settings.average_sale_count)
          .pluck(:sold_at, :final_price, :average_after_sale).reverse.map { Sale.new(*it) }
        Chart.new(sales:, floor: settings.minimum_price(rarity), rarity:, window_days: settings.average_window_days)
      end

      def self.fingerprint(card_season_id)
        sales_used, refreshed_at = EditionPrice.where(card_season_id:).where(sales_used: 1..).pick(:sales_used, :refreshed_at)
        Fingerprint.new(sales_used:, refreshed_at:) if refreshed_at
      end
    end
  end
end
