module Game
  module Market
    class DailySnapshot < ApplicationRecord
      self.table_name = "game_market_daily_snapshots"

      def readonly? = persisted?

      def average_price(rarity) = public_send(:"average_price_#{rarity}")
    end
  end
end
