module Game
  module Market
    # The accounts that open or trade like an alt account, read from the opened packs, the accepted trades, the sales and the bids.
    # Nothing here writes or sanctions: a signal is a hint for staff, with the facts behind it.
    module AltSignals
      SIGNALS = %w[near_maximum_opening one_way_trades sales_outside_price minimum_price_sales bids_on_tied_seller].freeze

      OPENING_CAPSULES_PER_DAY = 120
      OPENING_DAYS_REQUIRED = 3
      OPENING_WINDOW_DAYS = 7

      ONE_WAY_TRADES_REQUIRED = 10
      ONE_WAY_WINDOW_DAYS = 7
      ONE_WAY_COPIES_RATIO = 4

      MARKET_WINDOW_DAYS = 30
      OUTSIDE_PRICE_RATIO = 2
      OUTSIDE_PRICE_SALES_REQUIRED = 2
      MINIMUM_PRICE_SALES_REQUIRED = 3
      TIED_BID_LISTINGS_REQUIRED = 1

      Detected = Data.define(:account_id, :signal, :other_account_id, :facts) do
        def pair = [ account_id, other_account_id ].minmax
      end

      # A pair signal tells that two accounts act together; an account bidding on a listing of an account it is tied to is the third signal.
      def self.call(now: Time.current)
        pairs = OneWayTrades.call(now:) + SalesOutsidePrice.call(now:) + MinimumPriceSales.call(now:)
        CapsuleOpening.call(now:) + pairs + TiedBids.call(now:, ties: pairs.to_set(&:pair))
      end
    end
  end
end
