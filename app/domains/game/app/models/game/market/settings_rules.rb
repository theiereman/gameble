module Game
  module Market
    # The bounds of a change of the economy settings, read by the operation that enforces them and by the page that explains them.
    # A candidate holds an Integer or BigDecimal for a parsed value, nil for a blank one and a String for text that could not be read.
    class SettingsRules
      Violation = Data.define(:code, :values) do
        def initialize(code:, values: {}) = super
      end

      RARITIES = %i[common uncommon rare epic legendary].freeze
      ENTRUSTMENTS = RARITIES.map { :"entrustment_#{it}" }.freeze
      STAMPS = RARITIES.map { :"stamp_#{it}" }.freeze
      MINIMUMS = RARITIES.map { :"minimum_price_#{it}" }.freeze
      AMOUNTS = (ENTRUSTMENTS + STAMPS + MINIMUMS + [ :daily_cap ]).freeze
      TARGETS = RARITIES.map { :"income_days_target_#{it}" }.freeze
      DURATIONS = %i[duration_short_hours duration_medium_hours duration_long_hours].freeze
      TARGET_RANGE = BigDecimal("0.001")..BigDecimal("365")

      RANGES = {
        commission_basis_points: 0..2_500,
        increment_basis_points: 100..2_000,
        duration_short_hours: 1..720, duration_medium_hours: 1..720, duration_long_hours: 1..720,
        soft_close_seconds: 30..900,
        average_sale_count: 3..20,
        average_window_days: 7..365,
        feed_threshold_multiple: 2..100,
        unusual_maximum_multiple: 2..20,
        alert_destroyed_share_basis_points: 0..10_000,
        alert_picoins_per_player: 1..1_000_000_000_000,
        alert_top_share_basis_points: 1..10_000
      }.freeze

      OPTIONAL = (%i[alert_destroyed_share_basis_points alert_picoins_per_player alert_top_share_basis_points] + TARGETS).freeze
      EDITABLE = (AMOUNTS + RANGES.keys + [ :preselected_duration_hours ] + TARGETS).uniq.freeze
      REQUIRED = (EDITABLE - OPTIONAL).freeze

      # The least a minimum price can be for the seller not to lose: entrustment plus stamp, grossed up for the commission, to the next hundred.
      def self.floor(entrustment, stamp, commission_basis_points)
        (10_000 * (entrustment + stamp)).ceildiv(10_000 - commission_basis_points).ceildiv(100) * 100
      end

      def initialize(current)
        @current = current
      end

      def floor(entrustment, stamp, commission_basis_points) = self.class.floor(entrustment, stamp, commission_basis_points)

      # The least and the most an amount can become: half of the version in force, rounded up, and twice it.
      def amount_limits(field)
        value = @current.public_send(field)
        [ [ value.ceildiv(2), 1 ].max, value * 2 ]
      end

      def violations(candidate)
        candidate = candidate.to_h.symbolize_keys
        EDITABLE.each_with_object({}) do |field, found|
          violation = check(field, candidate)
          found[field] = violation if violation
        end
      end

      private

      def check(field, candidate)
        value = candidate[field]
        return if OPTIONAL.include?(field) && value.nil?
        return check_target(value) if TARGETS.include?(field)
        return Violation.new(code: :not_a_number) unless value.is_a?(Integer)

        if AMOUNTS.include?(field) then check_amount(field, value, candidate)
        elsif field == :preselected_duration_hours then check_preselected(value, candidate)
        else check_range(field, value) || check_ascending(field, candidate)
        end
      end

      def check_target(value)
        return Violation.new(code: :not_a_number) unless value.is_a?(BigDecimal)

        out_of_range(TARGET_RANGE) unless TARGET_RANGE.cover?(value)
      end

      def check_range(field, value)
        range = RANGES.fetch(field)
        out_of_range(range) unless range.cover?(value)
      end

      def out_of_range(range) = Violation.new(code: :out_of_range, values: { min: range.begin, max: range.end })

      def check_amount(field, value, candidate)
        least, most = amount_limits(field)
        return out_of_range(1..most) if value < 1
        return Violation.new(code: :more_than_double, values: { limit: most }) if value > most
        return Violation.new(code: :less_than_half, values: { limit: least }) if value < least

        check_floor(field, value, candidate) if MINIMUMS.include?(field)
      end

      def check_floor(field, value, candidate)
        rarity = field.to_s.delete_prefix("minimum_price_")
        entrustment, stamp, commission = candidate.values_at(:"entrustment_#{rarity}", :"stamp_#{rarity}", :commission_basis_points)
        return unless [ entrustment, stamp, commission ].all?(Integer)

        floor = floor(entrustment, stamp, commission_in_range(commission))
        Violation.new(code: :below_floor, values: { floor: }) if value < floor
      end

      def commission_in_range(commission)
        RANGES.fetch(:commission_basis_points).cover?(commission) ? commission : @current.commission_basis_points
      end

      def check_ascending(field, candidate)
        return unless field == :duration_medium_hours

        hours = candidate.values_at(*DURATIONS)
        Violation.new(code: :durations_not_ascending) if hours.all?(Integer) && hours.each_cons(2).any? { |shorter, longer| shorter >= longer }
      end

      def check_preselected(value, candidate)
        hours = candidate.values_at(*DURATIONS)
        Violation.new(code: :preselected_not_a_duration) if hours.all?(Integer) && !hours.include?(value)
      end
    end
  end
end
