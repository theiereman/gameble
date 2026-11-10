module Game
  module Market
    # Records the economy of one UTC day, once: a second run for the day, and a day before the market first opened, write nothing.
    # The closing circulation and the reconciliation's result come from the caller, so the operation never reads the clock.
    class WriteDailySnapshot < ApplicationOperation
      def call(day:, circulation:, balanced: true, wallet_differences: 0, circulation_difference: 0)
        return unless opened_by?(day)
        return if DailySnapshot.exists?(day:)

        figures = DailyFigures.of(day)
        transaction do
          snapshot = DailySnapshot.create!(
            **flows(figures), **prices, day:, circulation:, picoins_per_active_player: per_active_player(circulation, figures),
            median_daily_earnings: figures.median_daily_earnings, top_share_basis_points: figures.top_share_basis_points,
            reconciliation_balanced: balanced, wallet_differences:, circulation_difference:
          )
          step publish(DailySnapshotWritten.about(snapshot), stream_name: DailySnapshotWritten::STREAM)
          snapshot
        end
      rescue ActiveRecord::RecordNotUnique
        nil
      end

      private

      def opened_by?(day)
        first_opened_at = CurrentSettings.call&.first_opened_at
        !first_opened_at.nil? && day >= first_opened_at.utc.to_date
      end

      def flows(figures) = { created: figures.created, destroyed_total: figures.destroyed, forfeited: figures.forfeited }

      def prices = Catalog::Rarity::TIERS.values.to_h { [ :"average_price_#{it}", EditionPrice.rarity_average(it) ] }

      def per_active_player(circulation, figures) = (circulation.div(figures.active_players) if figures.active_players.positive?)
    end
  end
end
