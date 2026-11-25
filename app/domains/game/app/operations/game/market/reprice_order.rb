module Game
  module Market
    # A reprice replaces the order: the ledger takes one hold and one release per order.
    class RepriceOrder < Operation
      include PriceAmount

      def call(player:, order_id:, price:, settings_token:)
        player = step require_player(player)
        price = step amount(price)

        transaction do
          step lock_bank(player)
          settings = step current_settings(settings_token)
          replaced = step find_order(player, order_id)
          step still_open(replaced)
          step published(replaced.card_id)
          next replaced if price == replaced.price

          replaced.update!(status: "cancelled")
          Ledger.post(entry(replaced, :release, replaced.price))
          order = Order.create!(player:, card_id: replaced.card_id, settings:, price:, expires_at: settings.order_duration_days.days.from_now)
          step reaches_a_rarity(order)
          step covered(player, price)
          Ledger.post(entry(order, :hold, -price))
          step publish(OrderRepriced.about(replaced, order), stream_name: stream_name(player.id))
          order
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def current_settings(settings_token)
        settings = CurrentSettings.call
        return Failure(:market_closed) unless settings&.open
        return Failure(:amounts_changed) unless settings.token == settings_token

        Success(settings)
      end

      def published(card_id) = Catalog::PublishedCardIds.within([ card_id ]).any? ? Success() : Failure(:card_not_published)

      def find_order(player, order_id)
        order = Order.lock.find_by(id: order_id, player_id: player.id)
        order ? Success(order) : Failure(:order_not_found)
      end

      def still_open(order) = order.status == "open" ? Success() : Failure(:order_not_open)

      def reaches_a_rarity(order) = OrderRarities.call([ order.id ])[order.id].any? ? Success() : Failure(:order_below_minimum)

      def covered(player, price) = Balance.call(player).available >= price ? Success() : Failure(:not_covered)

      def entry(order, kind, available_delta)
        Ledger::Entry.new(player_id: order.player_id, kind:, available_delta:, committed_delta: -available_delta, order_id: order.id, settings_id: order.settings_id)
      end
    end
  end
end
