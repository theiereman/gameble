module Game
  module Market
    # A player's open buy orders, the soonest to end first, each with the card it is for and the rarities it reaches.
    module PlayerOrders
      Row = Data.define(:token, :card, :price, :expires_at, :rarities, :duration_days)

      def self.call(player:, locale:)
        orders = Order.where(player_id: player.id, status: "open").order(:expires_at, :id)
          .joins(:settings).pluck(:id, :token, :card_id, :price, :expires_at, "game_market_settings.order_duration_days")
        faces = Catalog::LatestPublishedCardSeasons.call(orders.map(&:third))
        cards = Catalog::CardViews.call(faces.values, locale:)
        rarities = OrderRarities.call(orders.map(&:first))
        orders.filter_map do |id, token, card_id, price, expires_at, duration_days|
          card = cards[faces[card_id]]
          Row.new(token:, card:, price:, expires_at:, rarities: rarities[id], duration_days:) if card
        end
      end

      def self.open_on(player, card_id) = Order.find_by(player_id: player.id, card_id:, status: "open")
    end
  end
end
