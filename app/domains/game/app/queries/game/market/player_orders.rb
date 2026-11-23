module Game
  module Market
    # A player's open buy orders, the soonest to end first, and the ones that ended this past week, the latest first:
    # each with the card it is for, the rarities it reaches and, once served, who sold it and the edition received.
    module PlayerOrders
      RECENT_FOR = 7.days
      ENDED_STATUSES = %w[served expired cancelled].freeze

      Groups = Data.define(:in_progress, :recent)
      Row = Data.define(:token, :card, :price, :expires_at, :rarities, :duration_days, :status, :ended_at, :seller, :served)

      def self.call(player:, locale:, now: Time.current)
        orders = shown(player, now).order(:expires_at, :id).joins(:settings)
          .pluck(:id, :token, :card_id, :price, :expires_at, "game_market_settings.order_duration_days", :status, :updated_at, :seller_id, :served_card_season_id)
        faces = Catalog::LatestPublishedCardSeasons.call(orders.map(&:third))
        cards = Catalog::CardViews.call(faces.values + orders.filter_map(&:last), locale:)
        sellers = Accounts::Player.where(id: orders.map { |*, seller_id, _served| seller_id }.compact).index_by(&:id)
        rarities = OrderRarities.call(orders.map(&:first))
        rows = orders.filter_map do |id, token, card_id, price, expires_at, duration_days, status, updated_at, seller_id, served_card_season_id|
          card = cards[faces[card_id]]
          next unless card

          Row.new(token:, card:, price:, expires_at:, rarities: rarities[id], duration_days:, status:, ended_at: (updated_at unless status == "open"),
            seller: sellers[seller_id], served: cards[served_card_season_id])
        end
        in_progress, recent = rows.partition { it.status == "open" }
        Groups.new(in_progress:, recent: recent.sort_by(&:ended_at).reverse)
      end

      def self.shown(player, now)
        mine = Order.where(player_id: player.id)
        mine.where(status: "open").or(mine.where(status: ENDED_STATUSES, updated_at: (now - RECENT_FOR)..))
      end
      private_class_method :shown

      def self.open_on(player, card_id) = Order.find_by(player_id: player.id, card_id:, status: "open")
    end
  end
end
