module Game
  module Market
    class WantedChoicesApplied < RubyEventStore::Event
      SALE_KEYS = %i[order_id buyer_id card_season_id price].freeze
      ENTRUSTED_KEYS = %i[card_season_id quantity].freeze

      def self.with(seller_id:, sales:, listing_ids:, entrusted:)
        new(data: { seller_id:, sales: only(sales, SALE_KEYS), listing_ids:, entrusted: only(entrusted, ENTRUSTED_KEYS) })
      end

      def self.only(rows, keys) = rows.map { |row| keys.index_with { row.fetch(it) } }
      private_class_method :only
    end
  end
end
