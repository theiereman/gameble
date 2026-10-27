module Catalog
  # How a season's cards are cut into the five rarity tiers when it is
  # published (CAP-3, AD-5). SHARES holds, once, each tier's share of the
  # season's cards counted from the top, in basis points keyed by the
  # Rarity::TIERS integers; common takes the rest. Starting values, to be
  # calibrated on the first real import.
  #
  # The cut is a pure function over the prestige scores, integers only: the
  # cards are ranked 1..N by score descending; for each tier from legendary down,
  # k = ceil(cumulative share × N / 10,000) and the tier's threshold is the
  # score at rank k. A card takes the highest tier whose threshold its score
  # reaches, common otherwise, so equal scores always share a tier.
  #
  #   Catalog::RarityThresholds.tiers([ 0.9, 0.5, … ]) # => [ 5, 1, … ] or nil
  module RarityThresholds
    SHARES = { 5 => 100, 4 => 400, 3 => 1_000, 2 => 2_500 }.freeze
    BASIS = 10_000
    COMMON = (Rarity::TIERS.keys - SHARES.keys).sole

    # Each tier's threshold, legendary first: { 5 => score, 4 => score, … }.
    # `scores` must not be empty.
    def self.thresholds(scores)
      raise ArgumentError, "no score to cut" if scores.empty?

      n = scores.size
      ranked = scores.sort.reverse
      cumulative = 0
      SHARES.keys.sort.reverse.to_h do |tier|
        cumulative += SHARES.fetch(tier)
        k = (cumulative * n + BASIS - 1) / BASIS
        [ tier, ranked[k - 1] ]
      end
    end

    # The tier of a score against thresholds from `thresholds`.
    def self.tier_of(score, thresholds)
      thresholds.each { |tier, threshold| return tier if score >= threshold }
      COMMON
    end

    # The tier of each score, in the order given; nil when a tier would hold
    # no card (too few scores, or one score covering two cuts).
    def self.tiers(scores)
      return nil if scores.empty?

      thresholds = thresholds(scores)
      tiers = scores.map { |score| tier_of(score, thresholds) }
      tiers if (Rarity::TIERS.keys - tiers.uniq).empty?
    end
  end
end
