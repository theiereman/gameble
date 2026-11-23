module Game
  module Market
    module AltSignals
      module OrderSalesToTiedBuyer
        def self.call(now:, ties:)
          return [] if ties.empty?

          served = Order.where(status: "served", served_at: (now - MARKET_WINDOW_DAYS.days)..)
            .joins("JOIN catalog_card_seasons ON catalog_card_seasons.id = game_market_orders.served_card_season_id")
            .joins("JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id")
            .joins("JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id")
            .order(:served_at, :id).pluck(:seller_id, :player_id, :price, "catalog_cards.slug", "catalog_seasons.number")
          served.filter_map { |seller_id, buyer_id, price, card, season| detected(seller_id, buyer_id, price, card, season, ties) }
        end

        def self.detected(seller_id, buyer_id, price, card, season, ties)
          return unless ties.include?([ seller_id, buyer_id ].minmax)

          Detected.new(account_id: seller_id, signal: "order_sale_to_tied_buyer", other_account_id: buyer_id,
            facts: { "card" => card, "season" => season, "price" => price })
        end

        private_class_method :detected
      end
    end
  end
end
