module Game
  module Market
    # How many public offers each listing holds: the one count the tiles and the history agree on.
    module OfferCounts
      def self.call(listing_ids) = Hash.new(0).merge!(Bid.public_outcomes.where(listing_id: listing_ids).group(:listing_id).count)
    end
  end
end
