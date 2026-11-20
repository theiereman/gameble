module Game
  module Market
    class ArchivePurchased < RubyEventStore::Event
      def self.with(player_id:, card_season_id:, price:) = new(data: { player_id:, card_season_id:, price: })
    end
  end
end
