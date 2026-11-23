module Game
  module Market
    class ExpireOrder < Operation
      NOT_DUE = Dry::Monads::Failure(:order_not_due)

      def call(player:, order_id:)
        player = step require_account(player)

        transaction do
          step lock_bank(player)
          order = step find_order(player, order_id)
          step due(order)
          order.update!(status: "expired")
          Ledger.post(Ledger::Entry.new(player_id: player.id, kind: :release, available_delta: order.price, committed_delta: -order.price,
            order_id: order.id, settings_id: order.settings_id))
          step publish(OrderExpired.about(order), stream_name: stream_name(player.id))
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

      def due(order) = order.status == "open" && order.expires_at <= Time.current ? Success() : NOT_DUE
    end
  end
end
