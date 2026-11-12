module Game
  module Market
    module AuctionMath
      BASIS_POINTS = 10_000
      PRICE_STEP = 100

      def self.commission(price, basis_points) = price * basis_points / BASIS_POINTS

      def self.increment(amount, basis_points) = (amount * basis_points).ceildiv(BASIS_POINTS).ceildiv(PRICE_STEP) * PRICE_STEP

      def self.displayed_price(highest:, second:, starting_price:, basis_points:)
        second ? [ highest, second + increment(second, basis_points) ].min : starting_price
      end

      def self.minimum_bid(price:, starting_price:, basis_points:) = price ? price + increment(price, basis_points) : starting_price

      def self.raise_minimum(maximum) = maximum + 1
    end
  end
end
