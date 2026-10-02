module Game
  # A draw (CAP-4, AD-7): a rarity tier picked by the odds, then a card-season
  # picked uniformly within that tier of the published season, so the size
  # of the catalog never dilutes the top tiers. Randomness is SecureRandom
  # unless a test passes a seeded Random.
  #
  #   pool = Game::DrawPool.current
  #   Game::Draw.pack(odds: Game::DrawOdds::REGULAR, size: 5, pool:) # => [card_season_id, …]
  module Draw
    # A tier drawn by the odds: random_number(TOTAL) against their cumulative
    # sums, the tiers in ascending order.
    def self.tier(odds:, random: SecureRandom)
      roll = random.random_number(DrawOdds::TOTAL)
      odds.keys.sort.each do |tier|
        roll -= odds.fetch(tier)
        return tier if roll.negative?
      end
      raise ArgumentError, "odds sum to less than #{DrawOdds::TOTAL}: #{odds.inspect}"
    end

    # A card-season id drawn uniformly within a tier of the pool.
    def self.card(tier:, random: SecureRandom, pool: DrawPool.current)
      ids = pool.tiers.fetch(tier)
      ids.fetch(random.random_number(ids.size))
    end

    # `size` card-season ids, each drawn independently: a tier by the odds,
    # then a card within it.
    def self.pack(odds:, size:, random: SecureRandom, pool: DrawPool.current)
      Array.new(size) { card(tier: tier(odds:, random:), random:, pool:) }
    end
  end
end
