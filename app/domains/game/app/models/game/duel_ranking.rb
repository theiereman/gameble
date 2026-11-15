module Game
  # One ranking group of a duel stat. Each entry is [id, key, measure]: the key orders the entries toward the stat's first
  # direction (a higher key ranks higher), the measure is the value in its natural unit, which the median distance is taken in.
  class DuelRanking
    Place = Data.define(:percentile, :median_distance)

    def initialize(entries)
      @entries = entries
    end

    # id => Place, the percentile a BigDecimal to one decimal and the distance a Float.
    def places
      return {} if @entries.empty?

      median = median_measure
      @entries.to_h do |id, key, measure|
        [ id, Place.new(percentile: percentile(key), median_distance: (measure - median).abs.to_f) ]
      end
    end

    private

    # The share of the group strictly below plus half of the equal ones, the entry itself included, rounded half up.
    def percentile(key)
      below, equal = counts.fetch(key)
      tenths = Rational(1_000 * (2 * below + equal), 2 * @entries.size).round(half: :up)
      BigDecimal(tenths) / 10
    end

    def counts
      @counts ||= begin
        below = 0
        @entries.map { it[1] }.tally.sort_by(&:first).to_h do |key, equal|
          [ key, [ below, equal ] ].tap { below += equal }
        end
      end
    end

    def median_measure
      sorted = @entries.map { it[2] }.sort
      middle = sorted.size / 2
      sorted.size.odd? ? sorted[middle] : Rational(sorted[middle - 1] + sorted[middle], 2)
    end
  end
end
