module Game
  module Market
    module ListingTokens
      def self.call(listing_ids) = Listing.where(id: listing_ids).pluck(:token)
    end
  end
end
