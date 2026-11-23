module Game
  module Market
    module AltSignals
      SIGNALS = %w[
        near_maximum_opening one_way_trades sales_outside_price minimum_price_sales bids_on_tied_seller order_sale_to_tied_buyer archive_purchase_of_tied_deposit
      ].freeze
      TYING = %w[one_way_trades sales_outside_price minimum_price_sales].freeze

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

      def self.call(now: Time.current)
        pairs = OneWayTrades.call(now:) + SalesOutsidePrice.call(now:) + MinimumPriceSales.call(now:)
        ties = pairs.to_set(&:pair)
        tied = TiedBids.call(now:, ties:) + OrderSalesToTiedBuyer.call(now:, ties:) + ArchivePurchasesOfTiedDeposit.call(now:, ties:)
        without_deleted_accounts(CapsuleOpening.call(now:) + pairs + tied)
      end

      def self.without_deleted_accounts(detected)
        ids = detected.flat_map { [ it.account_id, it.other_account_id ] }.compact.uniq
        deleted = Accounts::Player.where(id: ids).where.not(deleted_at: nil).pluck(:id).to_set
        detected.reject { deleted.include?(it.account_id) || deleted.include?(it.other_account_id) }
      end

      private_class_method :without_deleted_accounts
    end
  end
end
