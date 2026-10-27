module Game
  module FirstSessionGuarantee
    MIN_TIER = 3
    PACK = 10

    def self.apply(packs, pool:, random: SecureRandom)
      return packs if packs.size < PACK
      return packs if packs.first(PACK).any? { |cards| holds_rare_or_better?(cards, pool) }

      tenth = packs[PACK - 1].dup
      tenth[random.random_number(tenth.size)] = Draw.card(tier: Draw.tier(odds: DrawOdds::GUARANTEE, random:), random:, pool:)
      packs.dup.tap { |result| result[PACK - 1] = tenth }
    end

    def self.holds_rare_or_better?(cards, pool)
      cards.any? { |id| pool.tier_of(id) >= MIN_TIER }
    end

    private_class_method :holds_rare_or_better?
  end
end
