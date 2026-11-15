module Game
  class DuelStatRows
    Stat = Data.define(:value, :group, :key, :measure)

    STATS = {
      popularity: Stat.new(value: ->(m) { m.review_count }, group: ->(m) { m.season_id }, key: ->(m) { m.review_count },
        measure: ->(m) { m.review_count }),
      rating: Stat.new(value: ->(m) { m.rating }, group: ->(m) { m.season_id }, key: ->(m) { [ m.rating, m.review_count || 0 ] },
        measure: ->(m) { m.rating }),
      release: Stat.new(value: ->(m) { m.release_date }, group: ->(m) { m.season_id }, key: ->(m) { m.release_date.jd },
        measure: ->(m) { m.release_date.jd }),
      discovery: Stat.new(value: ->(m) { m.discovered_at }, group: ->(m) { m.season_id }, key: ->(m) { -m.discovered_at.to_r },
        measure: ->(m) { m.discovered_at.to_r }),
      circulation: Stat.new(value: ->(m) { m.holders }, group: ->(m) { [ m.season_id, m.rarity ] }, key: ->(m) { m.holders },
        measure: ->(m) { m.holders })
    }.freeze

    def initialize(measures, previous:, reason:, now:)
      @measures = measures
      @previous = previous
      @rotate = reason.to_s != "season"
      @now = now
    end

    def to_a
      places = STATS.to_h { |name, stat| [ name, ranked(stat) ] }
      @measures.map { |measure| row(measure, STATS.keys.to_h { |name| [ name, places.fetch(name)[measure.card_season_id] ] }) }
    end

    def self.trump(percentiles)
      ranked = DuelStat::STATS.each_with_index.filter_map do |name, index|
        percentile = percentiles[name]
        [ name, percentile, [ (percentile - 50).abs, -index ] ] unless percentile.nil?
      end
      name, percentile, = ranked.max_by(&:last)
      [ name.to_s, percentile >= 50 ? "high" : "low" ]
    end

    private

    def ranked(stat)
      @measures.reject { stat.value.(it).nil? }.group_by(&stat.group).each_value.with_object({}) do |group, places|
        places.merge!(DuelRanking.new(group.map { [ it.card_season_id, stat.key.(it), stat.measure.(it) ] }).places)
      end
    end

    def row(measure, places)
      percentiles = places.transform_values { it&.percentile }
      trump_stat, trump_direction = self.class.trump(percentiles)
      weekly = weekly_percentiles(measure.card_season_id, percentiles)
      columns = STATS.flat_map do |name, stat|
        place = places.fetch(name)
        [ [ :"#{name}_value", stat.value.(measure) ], [ :"#{name}_percentile", place&.percentile ],
          [ :"#{name}_median_distance", place&.median_distance ], [ :"#{name}_weekly_percentile", weekly.fetch(name) ] ]
      end
      { card_season_id: measure.card_season_id, **columns.to_h, trump_stat:, trump_direction:, computed_at: @now }
    end

    def weekly_percentiles(card_season_id, percentiles)
      before = @previous[card_season_id]
      return percentiles if before.nil?

      @rotate ? before.fetch(:percentiles) : before.fetch(:weekly)
    end
  end
end
