module Game
  module Market
    # The only reader of the daily snapshots: the four indicators over the 90 days ending on the last complete UTC day.
    # A day with no snapshot is nil for every indicator, never 0; a threshold or target is the settings version in force, flat over the window.
    module EconomySeries
      DAYS = 90
      RATIO_DAYS = 30

      Indicator = Data.define(:values, :threshold) do
        def last = values.last

        def last_threshold = threshold&.last
      end

      Series = Data.define(:days, :destroyed_share, :picoins_per_player, :top_share, :days_of_income, :latest)

      def self.call(now: Time.current, settings: CurrentSettings.call)
        last_day = now.utc.to_date - 1
        days = (last_day - (DAYS - 1))..last_day
        snapshots = DailySnapshot.where(day: (days.first - (RATIO_DAYS - 1))..last_day).index_by(&:day)
        build(days.to_a, snapshots, settings)
      end

      def self.build(days, snapshots, settings)
        Series.new(
          days:,
          destroyed_share: indicator(days, settings&.alert_destroyed_share_basis_points) { destroyed_share(it, snapshots) },
          picoins_per_player: indicator(days, settings&.alert_picoins_per_player) { snapshots[it]&.picoins_per_active_player },
          top_share: indicator(days, settings&.alert_top_share_basis_points) { snapshots[it]&.top_share_basis_points },
          days_of_income: Catalog::Rarity::TIERS.values.index_with { |rarity| days_of_income(rarity, days, snapshots, settings) },
          latest: snapshots.values_at(*days).compact.last
        )
      end
      private_class_method :build

      def self.indicator(days, threshold, &)
        Indicator.new(values: days.map(&), threshold: (Array.new(days.size, threshold) if threshold))
      end
      private_class_method :indicator

      def self.destroyed_share(day, snapshots)
        return unless snapshots.key?(day)

        window = snapshots.values_at(*((day - (RATIO_DAYS - 1))..day)).compact
        created = window.sum(&:created)
        (window.sum(&:destroyed) * 10_000).div(created) if created.positive?
      end
      private_class_method :destroyed_share

      def self.days_of_income(rarity, days, snapshots, settings)
        target = settings&.public_send(:"income_days_target_#{rarity}")
        indicator(days, target&.to_f) do |day|
          snapshot = snapshots[day]
          price = snapshot&.average_price(rarity)
          median = snapshot&.median_daily_earnings
          price.fdiv(median) if price && median&.positive?
        end
      end
      private_class_method :days_of_income
    end
  end
end
