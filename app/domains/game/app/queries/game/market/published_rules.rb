module Game
  module Market
    # The rules a player reads before the market has ever been used, as the settings version in force sets them; nil until the market first opened.
    module PublishedRules
      Rules = Data.define(
        :entrustment, :stamp, :minimum_price, :commission_basis_points, :daily_cap, :durations,
        :preselected_hours, :increment_basis_points, :soft_close_seconds, :unusual_maximum_multiple
      )

      def self.call
        settings = CurrentSettings.call
        return unless MarketState.call(settings).first_opened?

        Rules.new(
          entrustment: by_rarity { settings.entrustment(it) },
          stamp: by_rarity { settings.stamp(it) },
          minimum_price: by_rarity { settings.minimum_price(it) },
          commission_basis_points: settings.commission_basis_points,
          daily_cap: settings.daily_cap,
          durations: [ settings.duration_short_hours, settings.duration_medium_hours, settings.duration_long_hours ],
          preselected_hours: settings.preselected_duration_hours,
          increment_basis_points: settings.increment_basis_points,
          soft_close_seconds: settings.soft_close_seconds,
          unusual_maximum_multiple: settings.unusual_maximum_multiple
        )
      end

      def self.by_rarity(&) = Catalog::Rarity::TIERS.values.to_h { [ it, yield(it) ] }
      private_class_method :by_rarity
    end
  end
end
