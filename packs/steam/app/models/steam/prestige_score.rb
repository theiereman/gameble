module Steam
  # The prestige score of a game (CAP-3; epic 2 R5), the one place its
  # formula lives: a pure function of the Steam review score and review
  # count, nothing else (Metacritic never). Catalog::PublishSeason cuts the
  # rarity tiers from it.
  #
  # The Wilson lower bound of the positive share at 95 % (z = 1.96), plus
  # COUNT_WEIGHT × log10(review_count). Acclaim dominates; the count only
  # nudges, so a little-known game is never rare for being little known.
  # Strictly increasing in each input. A starting formula: COUNT_WEIGHT is
  # calibrated on the first real import, with the draft season's preview
  # (Catalog::DraftPreview) and a rescore (Steam::RescoreCards).
  #
  #   Steam::PrestigeScore.call(percent_positive: 95, review_count: 1_000) # => 0.9647…
  module PrestigeScore
    Z = 1.96
    COUNT_WEIGHT = 0.01

    # `percent_positive` an Integer 0–100, `review_count` an Integer ≥ 1;
    # anything else (nil included) raises ArgumentError.
    def self.call(percent_positive:, review_count:)
      unless percent_positive.is_a?(Integer) && percent_positive.between?(0, 100)
        raise ArgumentError, "percent_positive must be an Integer from 0 to 100, got #{percent_positive.inspect}"
      end
      unless review_count.is_a?(Integer) && review_count >= 1
        raise ArgumentError, "review_count must be an Integer of at least 1, got #{review_count.inspect}"
      end

      wilson_lower_bound(percent_positive.fdiv(100), review_count.to_f) + COUNT_WEIGHT * Math.log10(review_count)
    end

    def self.wilson_lower_bound(share, count)
      z2 = Z**2
      centre = share + z2 / (2 * count)
      spread = Z * Math.sqrt(share * (1 - share) / count + z2 / (4 * count**2))
      (centre - spread) / (1 + z2 / count)
    end
    private_class_method :wilson_lower_bound
  end
end
