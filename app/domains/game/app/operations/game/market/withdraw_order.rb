module Game
  module Market
    class WithdrawOrder < Operation
      NOT_WITHDRAWABLE = Dry::Monads::Failure(:order_not_withdrawable)

      def call(player:, order_id:)
        player = step require_account(player)

        transaction do
          TradeLocks.players(player.id)
          order = Order.lock.find_by(id: order_id, player_id: player.id)
          owner = step removed_owner_of_open(order)
          order.update!(status: "withdrawn")
          Ledger.post(Ledger::Entry.new(player_id: player.id, kind: :release, available_delta: order.price, committed_delta: -order.price,
            order_id: order.id, settings_id: order.settings_id))
          RefreshWanted.call(owner)
          step publish(OrderWithdrawn.about(order), stream_name: stream_name(player.id))
          order
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def removed_owner_of_open(order)
        owner = order&.status == "open" && Accounts::Player.removed.find_by(id: order.player_id)
        owner ? Success(owner) : NOT_WITHDRAWABLE
      end
    end
  end
end
