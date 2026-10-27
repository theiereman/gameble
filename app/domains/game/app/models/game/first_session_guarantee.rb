module Game
  # The first-session guarantee (CAP-4; catalog-and-rarity.md, Draw): a new
  # player gets a rare or better by their tenth pack. If none of the
  # first nine packs, in opening order, holds a card of tier 3 or above, one
  # card of the tenth, at a random position, is replaced by a card drawn from
  # tiers 3 to 5 in the regular odds' proportions (DrawOdds::GUARANTEE).
  # Nothing marks it.
  #
  #   Game::FirstSessionGuarantee.apply(packs, pool:) # => packs, the tenth changed if needed
  module FirstSessionGuarantee
    # The tier from which a card counts.
    MIN_TIER = 3
    # The pack that carries the forced card, counted from 1.
    PACK = 10

    # `packs`: arrays of card-season ids, in opening order. Returns new
    # arrays; the input is not changed.
    def self.apply(packs, pool:, random: SecureRandom)
      return packs if packs.size < PACK
      return packs if packs.first(PACK).any? { |cards| rare?(cards, pool) }

      tenth = packs[PACK - 1].dup
      tenth[random.random_number(tenth.size)] = Draw.card(tier: Draw.tier(odds: DrawOdds::GUARANTEE, random:), random:, pool:)
      packs.dup.tap { |result| result[PACK - 1] = tenth }
    end

    def self.rare?(cards, pool)
      cards.any? { |id| pool.tier_of(id) >= MIN_TIER }
    end

    private_class_method :rare?
  end
end
