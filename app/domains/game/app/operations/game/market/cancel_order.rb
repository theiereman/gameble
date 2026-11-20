module Game
  module Market
    class CancelOrder < Operation
      def call(player:, order_id:)
        player = step require_player(player)

        transaction do
          step lock_bank(player)
          order = step find_order(player, order_id)
          step still_open(order)
          order.update!(status: "cancelled")
          Ledger.post(Ledger::Entry.new(player_id: player.id, kind: :release, available_delta: order.price, committed_delta: -order.price,
            order_id: order.id, settings_id: order.settings_id))
          step publish(OrderCancelled.about(order), stream_name: stream_name(player.id))
          order
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def find_order(player, order_id)
        order = Order.lock.find_by(id: order_id, player_id: player.id)
        order ? Success(order) : Failure(:order_not_found)
      end

      def still_open(order) = order.status == "open" ? Success() : Failure(:order_not_open)
    end
  end
end
