module Game
  module Market
    # One version of every economy value. A version is never changed: a change inserts the next one, naming the version it replaces.
    class Settings < ApplicationRecord
      self.table_name = "game_market_settings"

      has_secure_token :token, length: 24

      def readonly? = persisted?

      def entrustment(rarity) = public_send(:"entrustment_#{rarity}")

      def stamp(rarity) = public_send(:"stamp_#{rarity}")

      def minimum_price(rarity) = public_send(:"minimum_price_#{rarity}")
    end
  end
end
