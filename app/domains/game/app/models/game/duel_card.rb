module Game
  class DuelCard < Data.define(:card_season_id, :card_id, :number, :rarity, :stats)
    Stat = Data.define(:value, :percentile, :median_distance)

    def self.from_snapshot(entry)
      stats = DuelStat::STATS.index_with do |name|
        stat = entry.fetch("stats").fetch(name.to_s)
        Stat.new(value: loaded(name, stat["value"]), percentile: stat["percentile"]&.then { BigDecimal(it.to_s) },
          median_distance: stat["median_distance"])
      end
      new(card_season_id: entry.fetch("card_season_id"), card_id: entry.fetch("card_id"), number: entry.fetch("number"),
        rarity: entry.fetch("rarity"), stats:)
    end

    def self.loaded(name, value)
      return if value.nil?

      case name
      when :release then Date.iso8601(value)
      when :discovery then Time.iso8601(value)
      else value
      end
    end
    private_class_method :loaded

    def initialize(stats:, **)
      super(stats: stats.dup.freeze, **)
    end

    def stat(name) = stats.fetch(name)

    def to_snapshot
      { "card_season_id" => card_season_id, "card_id" => card_id, "number" => number, "rarity" => rarity,
        "stats" => stats.to_h do |name, stat|
          [ name.to_s, { "value" => dumped(name, stat.value), "percentile" => stat.percentile&.to_f, "median_distance" => stat.median_distance } ]
        end }
    end

    private

    def dumped(name, value)
      return if value.nil?

      case name
      when :release then value.iso8601
      when :discovery then value.utc.iso8601(6)
      else value
      end
    end
  end
end
