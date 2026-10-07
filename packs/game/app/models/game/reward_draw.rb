module Game
  # The cards of a weekly goal's reward pack (CAP-12; the author's decision of
  # 2026-10-07): Pack::SIZE cards drawn with DrawOdds::REWARD, at least one of
  # them an Épique or better. When none is, one card at a random position is
  # replaced by a card drawn from DrawOdds::EPIC_OR_BETTER. Nothing marks it.
  #
  #   Game::RewardDraw.cards(pool:) # => [card_season_id, …] (5, one of tier 4 or 5 at least)
  module RewardDraw
    # The tier from which a card counts: Épique.
    MIN_TIER = 4

    def self.cards(pool:, random: SecureRandom)
      cards = Draw.pack(odds: DrawOdds::REWARD, size: Pack::SIZE, random:, pool:)
      return cards if cards.any? { |id| pool.tier_of(id) >= MIN_TIER }

      cards[random.random_number(cards.size)] = Draw.card(tier: Draw.tier(odds: DrawOdds::EPIC_OR_BETTER, random:), random:, pool:)
      cards
    end
  end
end
