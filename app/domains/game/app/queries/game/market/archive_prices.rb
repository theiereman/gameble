module Game
  module Market
    # The Archives' prices, one per rarity for a whole week from Monday 00:00 UTC: a coefficient times the rarity's reference. The reference is
    # the median auction sale of the rarity over 90 days, its top and bottom tenth left out, from five sales; under five, the back-office
    # reference, else a default. Each Monday the coefficient moves toward the share of minted PiCoins the market should destroy, a fifth at most.
    module ArchivePrices
      REFERENCES = { common: 35, uncommon: 100, rare: 150, epic: 1_650, legendary: 4_000 }.freeze
      REFERENCE_DAYS = 90
      MINIMUM_SALES = 5
      TRIMMED = Rational(1, 10)
      SET_POINT = Rational(3, 5)
      STARTING_COEFFICIENT = 6
      COEFFICIENTS = 2..10
      WEEKLY_STEP = Rational(1, 5)
      RATIO_WEEKS = 4
      ENTRUSTMENT_FLOOR = 5

      def self.week_start(now = Time.current) = now.utc.beginning_of_week

      # The week's price of every rarity.
      def self.call(settings, now: Time.current)
        week = week_start(now)
        Rails.cache.fetch([ "archive-prices", settings.token, week.to_i ], expires_in: 1.week) do
          coefficient = coefficient(week)
          SettingsRules::RARITIES.index_with { [ (coefficient * reference(settings, it, week)).round, floor(settings, it) ].max }
        end
      end

      # The least a Brotherhood auction of the rarity opens at.
      def self.reserve(settings, rarity, now: Time.current)
        [ COEFFICIENTS.begin * reference(settings, rarity, week_start(now)), floor(settings, rarity) ].max
      end

      # The shop already sells as dear as it may: destroying more is up to the amounts entrusting mints.
      def self.at_ceiling?(now = Time.current) = week_coefficient(now) >= COEFFICIENTS.end

      def self.week_coefficient(now = Time.current) = coefficient(week_start(now))

      def self.reference(settings, rarity, week)
        sold = EditionPrice.rarity_prices(rarity, since: week - REFERENCE_DAYS.days, before: week).sort
        cut = (sold.size * TRIMMED).floor
        return Median.of(sold[cut...(sold.size - cut)]) if sold.size >= MINIMUM_SALES

        settings.archive_price(rarity) || REFERENCES.fetch(rarity)
      end

      def self.floor(settings, rarity) = ENTRUSTMENT_FLOOR * settings.entrustment(rarity)

      # Starts once the Archives first sold a card; the weeks before keep the starting coefficient.
      def self.coefficient(week)
        first = ArchiveWithdrawal.minimum(:created_at) or return STARTING_COEFFICIENT
        coefficient = Rational(STARTING_COEFFICIENT)
        monday = week_start(first) + 1.week
        while monday <= week
          coefficient = step(coefficient, destroyed_share(monday))
          monday += 1.week
        end
        coefficient
      end

      def self.step(coefficient, share)
        return coefficient unless share

        factor = share.zero? ? 1 + WEEKLY_STEP : (SET_POINT / share).clamp(1 - WEEKLY_STEP, 1 + WEEKLY_STEP)
        (coefficient * factor).clamp(COEFFICIENTS.begin, COEFFICIENTS.end)
      end

      # Destroyed over minted PiCoins in the four weeks before a Monday, nil when nothing was minted.
      def self.destroyed_share(monday)
        entries = LedgerEntry.where(created_at: (monday - RATIO_WEEKS.weeks)...monday)
        minted = entries.where(kind: "mint").sum(:available_delta)
        Rational(-entries.where(kind: LedgerEntry::DESTROYED_KINDS).sum(:available_delta), minted) if minted.positive?
      end

      private_class_method :reference, :floor, :coefficient, :step, :destroyed_share
    end
  end
end
