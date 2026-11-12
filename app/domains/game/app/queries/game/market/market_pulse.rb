module Game
  module Market
    # The market at a glance: how many listings are open, how many end within the hour, the first of those, and the PiCoins traded lately.
    module MarketPulse
      SOON = 1.hour

      Pulse = Data.define(:open, :ending_soon, :soonest, :volume)

      def self.call(locale:, limit: 4, now: Time.current)
        open = Listing.open_now.where("ends_at > ?", now)
        soon = open.where(ends_at: ..(now + SOON))
        Pulse.new(open: open.count, ending_soon: soon.count, soonest: OpenListings.rows(soon.order(:ends_at, :id).limit(limit), locale:),
          volume: TradedVolume.call(now:))
      end
    end
  end
end
