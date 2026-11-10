module Game
  module Market
    class RefreshEditionPrices < ApplicationOperation
      def call(now: Time.current)
        settings = CurrentSettings.call
        return 0 if settings.nil?

        EditionPrice.where("sales_used > 0").order(:id).pluck(:id).count { refresh(it, settings, now) }
      end

      private

      def refresh(id, settings, now)
        EditionPrice.transaction do
          row = EditionPrice.lock.find(id)
          prices = EditionPrice.sales_in_window(row.card_season_id, settings:, now:)
          average = EditionPrice.average_of(prices)
          next false if row.average == average && row.sales_used == prices.size

          row.update!(average:, sales_used: prices.size, refreshed_at: now)
          true
        end
      end
    end
  end
end
