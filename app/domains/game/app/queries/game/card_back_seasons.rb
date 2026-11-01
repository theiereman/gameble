module Game
  module CardBackSeasons
    def self.call(player) = of(EarnedSetBacks.rows(player))

    def self.of(rows)
      rows.group_by { |kind, key, _, _| CardBacks.set_key(kind, key) }.transform_values { |earned| earned.map { it[2] }.uniq.sort }
    end
  end
end
