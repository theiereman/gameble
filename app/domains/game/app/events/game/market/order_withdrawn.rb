module Game
  module Market
    class OrderWithdrawn < RubyEventStore::Event
      def self.about(order) = new(data: { order_id: order.id, player_id: order.player_id, card_id: order.card_id, amount: order.price })
    end
  end
end
