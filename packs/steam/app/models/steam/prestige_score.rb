module Steam
  # The prestige score of a game (CAP-3; epic 2 R5), the one place its
  # formula lives: a pure function of the Steam review score and review
  # count, nothing else (Metacritic never). Catalog::PublishSeason cuts the
  # rarity tiers from it.
  #
  # log10(review_count) + SHARE_WEIGHT × the Wilson lower bound of the
  # positive share at 95 % (z = 1.96). Popularity leads and acclaim
  # separates: a tenfold count is worth one point, the share at most
  # SHARE_WEIGHT points, so the best-known games are the rarest and, among
  # games known alike, the better liked one ranks higher. Strictly
  # increasing in each input.
  #
  # Chosen by the author on 2026-10-06 (story 2.12), after a simulation on
  # the 12,326 games of the first real import: with SHARE_WEIGHT = 4 the
  # Légendaires are games with about 93k reviews or more and at least 76 %
  # positive (Counter-Strike 2, Dota 2, Elden Ring, Skyrim…), where the
  # earlier Wilson + 0.01 × log10(count) made small acclaimed games
  # Légendaires. It applies from the next publication or rescore
  # (Steam::RescoreCards); a published season never changes.
  #
  #   Steam::PrestigeScore.call(percent_positive: 95, review_count: 1_000) # => 6.7387…
  module PrestigeScore
    Z = 1.96
    SHARE_WEIGHT = 4

    # `percent_positive` an Integer 0–100, `review_count` an Integer ≥ 1;
    # anything else (nil included) raises ArgumentError.
    def self.call(percent_positive:, review_count:)
      unless percent_positive.is_a?(Integer) && percent_positive.between?(0, 100)
        raise ArgumentError, "percent_positive must be an Integer from 0 to 100, got #{percent_positive.inspect}"
      end
      unless review_count.is_a?(Integer) && review_count >= 1
        raise ArgumentError, "review_count must be an Integer of at least 1, got #{review_count.inspect}"
      end

      Math.log10(review_count) + SHARE_WEIGHT * wilson_lower_bound(percent_positive.fdiv(100), review_count.to_f)
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
