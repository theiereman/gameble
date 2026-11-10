module Game
  module Handlers
    module SaleFeed
      def self.call(event)
        data = event.data
        FeedEntry.record_sale(listing_id: data.fetch(:listing_id), buyer_id: data.fetch(:winner_id), card_season_id: data.fetch(:card_season_id),
          price: data.fetch(:final_price), settings: Market::CurrentSettings.call, at: event.metadata[:timestamp] || Time.current)
      end
    end
  end
end
