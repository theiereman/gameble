module Game
  module Market
    # Serves one buy order with one of the seller's free copies, under the locks the caller holds; returns the ledger entries to post.
    module OrderServing
      include AuctionSettlement

      private

      def serve_order(order:, seller_id:, card_season_id:, holdings:, commission_settings:, now:)
        move_order_copy(order:, seller_id:, card_season_id:, holdings:, now:)
        settle_order(order:, seller_id:, card_season_id:, commission_settings:, now:)
      end

      def move_order_copy(order:, seller_id:, card_season_id:, holdings:, now:)
        give_sold_copy(seller_id, holdings, card_season_id, released: {}, now:)
        receive_bought_copy(order.player_id, holdings, card_season_id, now:)
      end

      # Two orders served on one edition settle one after the other: the second's window then holds the first.
      def settle_order(order:, seller_id:, card_season_id:, commission_settings:, now:)
        average = refresh_edition_price(card_season_id, now, adding: order.price)
        order.update!(status: "served", seller_id:, served_card_season_id: card_season_id, served_at: now, average_after_sale: average)
        sale_entries(buyer_id: order.player_id, seller_id:, price: order.price, held: order.price, reference: { order_id: order.id },
          settings_id: order.settings_id, commission_settings:)
      end
    end
  end
end
