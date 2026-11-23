module Game
  module Handlers
    module SaleFeed
      def self.call(event)
        settings = Market::CurrentSettings.call
        at = event.metadata[:timestamp] || Time.current
        sales(event).each { FeedEntry.record_sale(**it, settings:, at:) }
      end

      def self.sales(event)
        data = event.data
        case event
        when Market::AuctionSold
          [ { listing_id: data.fetch(:listing_id), buyer_id: data.fetch(:winner_id), card_season_id: data.fetch(:card_season_id), price: data.fetch(:final_price) } ]
        when Market::OrderServed
          [ order_sale(data) ]
        when Market::WantedChoicesApplied
          data.fetch(:sales).map { order_sale(it) }.sort_by { [ it[:buyer_id], it[:order_id] ] }
        end
      end
      private_class_method :sales

      def self.order_sale(sale) = %i[order_id buyer_id card_season_id price].index_with { sale.fetch(it) }
      private_class_method :order_sale
    end
  end
end
