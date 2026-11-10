module Game
  module Market
    module ListingBidders
      def self.call(listing_id)
        Bid.public_outcomes.where(listing_id:).distinct.pluck(:player_id)
      end
    end
  end
end
