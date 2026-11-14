module Game
  module FortuneDistribution
    BANDS = 49
    LEVELS = 18
    CACHE_LIFETIME = 5.minutes

    HEAT_CEILINGS = { cold: 0.12, cool: 0.5, warm: 0.8 }.freeze

    BAND_SQL = "ROUND((#{FortuneIndex::LIMIT} * TANH(game_fortunes.z_score / 2) + #{FortuneIndex::LIMIT}) * #{BANDS - 1} / #{2 * FortuneIndex::LIMIT})::integer".freeze

    Column = Data.define(:level, :heat)

    Result = Data.define(:counts) do
      def total = counts.sum

      def peak = counts.max

      def crowded_index = FortuneDistribution.index_of(counts.index(peak))

      def columns = counts.map { |count| FortuneDistribution.column(count, peak) }
    end

    def self.call(period = :week, now: Time.current)
      key = [ "game/fortune_distribution", period, WeeklyGoal.week_start(now).iso8601 ]
      Result.new(counts: Rails.cache.fetch(key, expires_in: CACHE_LIFETIME) { read(period, now) })
    end

    def self.band_of(index) = ((index + FortuneIndex::LIMIT) * (BANDS - 1) / (2.0 * FortuneIndex::LIMIT)).round

    def self.index_of(band) = ((band * 2.0 * FortuneIndex::LIMIT / (BANDS - 1)) - FortuneIndex::LIMIT).round

    def self.column(count, peak)
      share = peak.positive? ? count.fdiv(peak) : 0.0
      Column.new(level: (share * LEVELS).round, heat: heat(share))
    end

    def self.heat(share) = HEAT_CEILINGS.find { |_, ceiling| share < ceiling }&.first || :hot

    def self.read(period, now)
      by_band = Fortune.of_period(period, now).listed.group(Arel.sql(BAND_SQL)).count
      Array.new(BANDS) { |band| by_band.fetch(band, 0) }
    end

    private_class_method :heat, :read
  end
end
