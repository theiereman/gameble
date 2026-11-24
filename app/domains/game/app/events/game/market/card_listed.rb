module Game
  module Market
    class CardListed < RubyEventStore::Event
      CONVERTED_KEYS = %i[order_id owner_id listing_id price status].freeze

      def self.with(listing_id:, seller_id:, card_season_id:, converted: [])
        new(data: { listing_id:, seller_id:, card_season_id:, converted: converted.map { |row| CONVERTED_KEYS.index_with { row.fetch(it) } } })
      end
    end
  end
end
