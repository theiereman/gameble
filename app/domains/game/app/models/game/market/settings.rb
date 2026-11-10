module Game
  module Market
    # One version of every economy value. A version is never changed: a change inserts the next one, naming the version it replaces.
    class Settings < ApplicationRecord
      self.table_name = "game_market_settings"

      has_secure_token :token, length: 24

      def readonly? = persisted?

      NOT_CARRIED = %w[id token author_id replaces_id created_at].freeze

      # The unsaved next version: every value of this one, the given changes, and this one named as the version it replaces.
      def successor(author:, **changes)
        self.class.new(attributes.except(*NOT_CARRIED).merge(changes.stringify_keys).merge("author_id" => author.id, "replaces_id" => id))
      end

      def entrustment(rarity) = public_send(:"entrustment_#{rarity}")

      def stamp(rarity) = public_send(:"stamp_#{rarity}")

      def minimum_price(rarity) = public_send(:"minimum_price_#{rarity}")
    end
  end
end
