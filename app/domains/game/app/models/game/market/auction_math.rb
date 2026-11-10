module Game
  module Market
    module AuctionMath
      BASIS_POINTS = 10_000

      def self.commission(price, basis_points) = price * basis_points / BASIS_POINTS
    end
  end
end
