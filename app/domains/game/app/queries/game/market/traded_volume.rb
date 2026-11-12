module Game
  module Market
    # The PiCoins paid for sold auctions on each of the last two weeks' days, today included.
    module TradedVolume
      DAYS = 14
      WEEK = 7
      CACHE_LIFETIME = 5.minutes

      Volume = Data.define(:days, :amounts) do
        def week = amounts.last(WEEK).sum

        def week_before = amounts.first(amounts.size - WEEK).last(WEEK).sum

        def change_percent = (((week - week_before) * 100.0 / week_before).round if week_before.positive?)

        def traded? = amounts.any?(&:positive?)
      end

      def self.call(now: Time.current)
        today = now.utc.to_date
        days = ((today - (DAYS - 1))..today).to_a
        sums = Rails.cache.fetch([ "game/market/traded_volume", today.iso8601 ], expires_in: CACHE_LIFETIME) { read(days.first) }
        Volume.new(days:, amounts: days.map { sums.fetch(it, 0) })
      end

      def self.read(first_day)
        Listing.sold.where(sold_at: Time.utc(first_day.year, first_day.month, first_day.day)..)
          .group(Arel.sql("date(sold_at)")).sum(:final_price).transform_values(&:to_i)
      end

      private_class_method :read
    end
  end
end
