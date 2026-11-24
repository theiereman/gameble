module Game
  module Market
    # A holder sells one free copy straight to the best eligible order they saw: no stamp, the commission at the version they confirmed.
    class SellToOrder < Operation
      include OrderServing

      ORDER_CHANGED = Dry::Monads::Failure(:best_order_changed)

      def call(player:, card_season_id:, order_token:, settings_token:)
        player = step require_player(player)
        now = Time.current
        seen = step seen_order(card_season_id, player, order_token.to_s, now)

        transaction do
          TradeLocks.players(player.id, seen.player_id)
          step lock_bank(player)
          settings = step current_settings(settings_token.to_s)
          step direct_sale_rarity(card_season_id)
          holdings = lock_sale_holdings(player.id, seen.player_id, card_season_id)
          order = Order.lock.find(seen.id)
          step still_best(card_season_id, player, seen, now)
          step free_copy(holdings.fetch(player.id)[card_season_id])
          Ledger.post(serve_order(order:, seller_id: player.id, card_season_id:, holdings:, commission_settings: settings, now:))
          step publish(OrderServed.about(order), stream_name: stream_name(player.id))
          order
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def seen_order(card_season_id, player, order_token, now)
        best = BestEligibleOrder.call(card_season_id, except: player.id, now:)
        best && order_token.present? && best.token == order_token ? Success(best) : ORDER_CHANGED
      end

      def still_best(card_season_id, player, seen, now)
        BestEligibleOrder.call(card_season_id, except: player.id, now:)&.id == seen.id ? Success() : ORDER_CHANGED
      end

      def current_settings(settings_token)
        settings = CurrentSettings.call
        return Failure(:market_closed) unless settings&.open
        return Failure(:amounts_changed) unless settings.token == settings_token

        Success(settings)
      end

      def direct_sale_rarity(card_season_id) = DirectSale.edition?(card_season_id) ? Success() : Failure(:direct_sale_not_for_rarity)

      def free_copy(holding) = holding && holding.quantity > holding.reserved ? Success() : Failure(:copy_not_free)
    end
  end
end
