module Game
  module RewardDraw
    MIN_TIER = 4

    def self.cards(pool:, random: SecureRandom)
      cards = Draw.pack(odds: DrawOdds::REWARD, size: Pack::SIZE, random:, pool:)
      return cards if holds_epic_or_better?(cards, pool)

      cards[random.random_number(cards.size)] = Draw.card(tier: Draw.tier(odds: DrawOdds::EPIC_OR_BETTER, random:), random:, pool:)
      cards
    end

    def self.holds_epic_or_better?(cards, pool)
      cards.any? { |id| pool.tier_of(id) >= MIN_TIER }
    end

    private_class_method :holds_epic_or_better?
  end
end
