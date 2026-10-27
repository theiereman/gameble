module Steam
  # The prestige score of a game, the one place its formula lives: the
  # review count, plus the share of positive reviews in thousandths. The
  # count alone ranks games; the share, worth at most 0.1, only orders games
  # with the same count. Catalog::PublishSeason cuts the rarity tiers from it.
  #
  # VERSION names this formula on every card-season it scores, so a season
  # is never published with scores of two formulas: bump it whenever the
  # formula changes.
  #
  #   Steam::PrestigeScore.call(percent_positive: 98, review_count: 5_000) # => 5000.098
  module PrestigeScore
    VERSION = 3
    PERCENT_SCALE = 1_000

    # `percent_positive` an Integer 0–100, `review_count` an Integer ≥ 1;
    # anything else (nil included) raises ArgumentError.
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
