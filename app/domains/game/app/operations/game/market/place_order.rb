module Game
  module Market
    class PlaceOrder < Operation
      include PriceAmount

      def call(player:, card_id:, price:, settings_token:)
        player = step require_player(player)
        price = step amount(price)

        transaction do
          step lock_bank(player)
          settings = step current_settings(settings_token)
          step published(card_id)
          step none_open(player, card_id)
          order = Order.create!(player:, card_id:, settings:, price:, expires_at: settings.order_duration_days.days.from_now)
          step reaches_a_rarity(order)
          step covered(player, price)
          Ledger.post(Ledger::Entry.new(player_id: player.id, kind: :hold, available_delta: -price, committed_delta: price, order_id: order.id, settings_id: settings.id))
          step publish(OrderPlaced.about(order), stream_name: stream_name(player.id))
          order
        end
      rescue ActiveRecord::RecordNotUnique
        step Failure(:order_already_open)
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

      def none_open(player, card_id)
        Order.where(player_id: player.id, card_id:, status: "open").exists? ? Failure(:order_already_open) : Success()
      end

      def reaches_a_rarity(order) = OrderRarities.call([ order.id ])[order.id].any? ? Success() : Failure(:order_below_minimum)

      def covered(player, price) = Balance.call(player).available >= price ? Success() : Failure(:more_than_available)
    end
  end
end
