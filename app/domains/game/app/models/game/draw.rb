module Game
  module Draw
    def self.tier(odds:, random: SecureRandom)
      roll = random.random_number(DrawOdds::TOTAL)
      odds.keys.sort.each do |tier|
        roll -= odds.fetch(tier)
        return tier if roll.negative?
      end
      raise ArgumentError, "odds sum to less than #{DrawOdds::TOTAL}: #{odds.inspect}"
    end

    def self.card(tier:, random: SecureRandom, pool: DrawPool.current)
      ids = pool.tiers.fetch(tier)
      ids.fetch(random.random_number(ids.size))
    end

    def self.pack(odds:, size:, random: SecureRandom, pool: DrawPool.current)
      Array.new(size) { card(tier: tier(odds:, random:), random:, pool:) }
    end

    def self.in_tiers(tiers, random: SecureRandom, pool: DrawPool.current)
      tiers.map { |tier| card(tier:, random:, pool:) }
    end
  end
end
