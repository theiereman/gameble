module Game
  module Market
    class OrderRepriced < RubyEventStore::Event
      def self.about(replaced, order)
        new(data: { replaced_order_id: replaced.id, order_id: order.id, player_id: order.player_id, card_id: order.card_id, previous_amount: replaced.price,
          amount: order.price })
      end
    end
  end
end
