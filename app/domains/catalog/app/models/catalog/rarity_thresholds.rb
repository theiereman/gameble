module Catalog
  module RarityThresholds
    SHARES = { 5 => 100, 4 => 400, 3 => 1_000, 2 => 2_500 }.freeze
    BASIS = 10_000
    COMMON = (Rarity::TIERS.keys - SHARES.keys).sole

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

    def self.tier_of(score, thresholds)
      thresholds.each { |tier, threshold| return tier if score >= threshold }
      COMMON
    end

    def self.tiers(scores)
      return nil if scores.empty?

      thresholds = thresholds(scores)
      tiers = scores.map { |score| tier_of(score, thresholds) }
      tiers if (Rarity::TIERS.keys - tiers.uniq).empty?
    end
  end
end
