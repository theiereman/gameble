module Game
  module Market
    # The one way a request reaches a listing's id without carrying it: its token in, the id out, for the server's own use.
    module ListingIdByToken
      def self.call(token) = Listing.where(token: token.to_s).pick(:id)
    end
  end
end
