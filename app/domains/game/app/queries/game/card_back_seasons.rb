module Game
  module CardBackSeasons
    def self.call(player)
      EarnedSetBacks.rows(player).each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(kind, key, number), seasons|
        seasons[CardBacks.set_key(kind, key)] << number
      end.transform_values { it.uniq.sort }
    end
  end
end
