module Game
  module Market
    # One movement of PiCoins, kept for good: it can be neither changed nor removed.
    class LedgerEntry < ApplicationRecord
      self.table_name = "game_market_ledger_entries"

      KINDS = %w[mint stamp hold release purchase sale commission forfeit archive_purchase slot_purchase].freeze
      DESTROYED_KINDS = %w[stamp commission forfeit archive_purchase slot_purchase].freeze

      def readonly? = persisted?
    end
  end
end
