module Game
  module Market
    # The accounts that open or trade like an alt account, read from the opened packs and the accepted trades.
    # Nothing here writes or sanctions: a signal is a hint for staff, with the facts behind it.
    module AltSignals
      SIGNALS = %w[near_maximum_opening one_way_trades].freeze

      OPENING_CAPSULES_PER_DAY = 120
      OPENING_DAYS_REQUIRED = 3
      OPENING_WINDOW_DAYS = 7

      ONE_WAY_TRADES_REQUIRED = 10
      ONE_WAY_WINDOW_DAYS = 7
      ONE_WAY_COPIES_RATIO = 4

      Detected = Data.define(:account_id, :signal, :other_account_id, :facts)

      def self.call(now: Time.current)
        CapsuleOpening.call(now:) + OneWayTrades.call(now:)
      end
    end
  end
end
