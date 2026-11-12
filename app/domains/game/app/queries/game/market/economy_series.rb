module Game
  module Market
    module EconomySeries
      DAYS = 90
      RATIO_DAYS = 30
      REACTOR_DAYS = 30

      Indicator = Data.define(:values, :threshold) do
        def last = values.last

        def last_threshold = threshold&.last
      end

      Series = Data.define(:days, :destroyed_share, :picoins_per_player, :top_share, :days_of_income, :latest)

      def self.call(now: Time.current, settings: CurrentSettings.call)
        days = window(now, DAYS)
        snapshots = DailySnapshot.where(day: (days.first - (RATIO_DAYS - 1))..days.last).index_by(&:day)
        build(days, snapshots, settings)
      end

      def self.reactor(now: Time.current, through: now.utc.to_date - 1)
        days = days_through(through, REACTOR_DAYS)
        Reactor.of(days, DailySnapshot.where(day: days.first..days.last).index_by(&:day))
      end

      def self.rarity_prices(now: Time.current, through: now.utc.to_date - 1)
        days = days_through(through, DAYS)
        snapshots = DailySnapshot.where(day: days.first..days.last).index_by(&:day)
        RarityPrices.of(days, Catalog::Rarity::TIERS.values.index_with { days_of_income(it, days, snapshots, nil).values })
      end

      def self.last_day = DailySnapshot.maximum(:day)

      def self.window(now, length) = days_through(now.utc.to_date - 1, length)
      private_class_method :window

      def self.days_through(last_day, length) = ((last_day - (length - 1))..last_day).to_a
      private_class_method :days_through

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
        (window.sum(&:destroyed_total) * 10_000).div(created) if created.positive?
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
