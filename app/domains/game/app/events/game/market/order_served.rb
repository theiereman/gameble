module Game
  module Market
    class OrderServed < RubyEventStore::Event
      def self.about(order)
        new(data: { order_id: order.id, buyer_id: order.player_id, seller_id: order.seller_id, card_season_id: order.served_card_season_id,
          price: order.price })
      end
    end
  end
end
