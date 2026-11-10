module Game
  module Market
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
