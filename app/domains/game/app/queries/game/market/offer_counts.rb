module Game
  module Market
    module OfferCounts
      def self.call(listing_ids) = Hash.new(0).merge!(Bid.public_outcomes.where(listing_id: listing_ids).group(:listing_id).count)
    end
  end
end
