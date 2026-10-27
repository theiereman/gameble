module Steam
  module PrestigeScore
    VERSION = 3
    PERCENT_SCALE = 1_000

    def self.call(percent_positive:, review_count:)
      unless percent_positive.is_a?(Integer) && percent_positive.between?(0, 100)
        raise ArgumentError, "percent_positive must be an Integer from 0 to 100, got #{percent_positive.inspect}"
      end
      unless review_count.is_a?(Integer) && review_count >= 1
        raise ArgumentError, "review_count must be an Integer of at least 1, got #{review_count.inspect}"
      end

      review_count + percent_positive.fdiv(PERCENT_SCALE)
    end
  end
end
