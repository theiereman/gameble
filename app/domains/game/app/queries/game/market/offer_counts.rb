module Game
  module Market
    # How many public offers each listing holds. No offer exists yet, so every count is zero.
    module OfferCounts
      def self.call(_listing_ids) = Hash.new(0)
    end
  end
end
