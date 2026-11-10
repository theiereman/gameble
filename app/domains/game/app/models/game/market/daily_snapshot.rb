module Game
  module Market
    # The economy's figures for one UTC day, kept for good: written once by WriteDailySnapshot, never changed.
    class DailySnapshot < ApplicationRecord
      self.table_name = "game_market_daily_snapshots"

      def readonly? = persisted?

      def average_price(rarity) = public_send(:"average_price_#{rarity}")
    end
  end
end
