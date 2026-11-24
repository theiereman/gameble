module Game
  module Market
    class WantedChoicesApplied < RubyEventStore::Event
      SALE_KEYS = %i[order_id buyer_id card_season_id price].freeze
      ENTRUSTED_KEYS = %i[card_season_id quantity].freeze

      def self.with(seller_id:, sales:, listing_ids:, entrusted:, converted: [])
        new(data: { seller_id:, sales: only(sales, SALE_KEYS), listing_ids:, entrusted: only(entrusted, ENTRUSTED_KEYS),
          converted: only(converted, CardListed::CONVERTED_KEYS) })
      end

      def self.buyer_ids(data) = data.fetch(:sales).map { it.fetch(:buyer_id) }

      def self.player_ids(data) = [ data.fetch(:seller_id), *buyer_ids(data) ]

      def self.only(rows, keys) = rows.map { |row| keys.index_with { row.fetch(it) } }
      private_class_method :only
    end
  end
end
