module Game
  module Market
    # The price state of each asked card-season, for display. Nothing at all before the market's first opening.
    module EditionPrices
      Price = Data.define(:average, :sales_used) do
        def priced? = !average.nil? && sales_used >= EditionPrice::MINIMUM_SALES

        def few_sales? = !average.nil? && !priced?

        def no_sale? = average.nil?
      end

      NO_SALE = Price.new(average: nil, sales_used: 0)

      def self.call(card_season_ids, state: MarketState.call)
        return {} unless state.first_opened?

        ids = Array(card_season_ids).uniq
        rows = EditionPrice.where(card_season_id: ids).pluck(:card_season_id, :average, :sales_used)
          .to_h { |id, average, sales_used| [ id, Price.new(average:, sales_used:) ] }
        ids.to_h { [ it, rows.fetch(it, NO_SALE) ] }
      end
    end
  end
end
