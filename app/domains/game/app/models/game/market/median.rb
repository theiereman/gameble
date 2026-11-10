module Game
  module Market
    # The middle of a list of integers, the mean of the two middle ones rounded down for an even count, nil for none.
    module Median
      def self.of(values)
        return if values.empty?

        sorted = values.sort
        middle = sorted.size.div(2)
        sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]).div(2)
      end
    end
  end
end
