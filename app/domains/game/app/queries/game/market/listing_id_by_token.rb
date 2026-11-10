module Game
  module Market
    module ListingIdByToken
      def self.call(token) = Listing.where(token: token.to_s).pick(:id)
    end
  end
end
