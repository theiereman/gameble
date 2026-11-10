module Game
  module Market
    module AltSignals
      module TiedBids
        def self.call(now:, ties:)
          return [] if ties.empty?

          placed = Bid.history_visible.where(created_at: (now - MARKET_WINDOW_DAYS.days)..).joins(:listing)
            .group(:player_id, "game_market_listings.seller_id")
            .pluck(:player_id, "game_market_listings.seller_id", Arel.sql("COUNT(DISTINCT game_market_bids.listing_id)"), Arel.sql("COUNT(*)"))
          placed.filter_map { |bidder_id, seller_id, listings, bids| detected(bidder_id, seller_id, listings, bids, ties) }
        end

        def self.detected(bidder_id, seller_id, listings, bids, ties)
          return unless ties.include?([ bidder_id, seller_id ].minmax) && listings >= TIED_BID_LISTINGS_REQUIRED

          Detected.new(account_id: bidder_id, signal: "bids_on_tied_seller", other_account_id: seller_id, facts: { "listings" => listings, "bids" => bids })
        end

        private_class_method :detected
      end
    end
  end
end
