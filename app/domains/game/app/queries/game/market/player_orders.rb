module Game
  module Market
    # A player's open buy orders, the soonest to end first, and the ones that ended this past week, the latest first:
    # each with the card it is for, the rarities it reaches and, once served, who sold it and the edition received.
    # An order turned into a bid reads from its auction: in the auction while that is open and its owner leads, won once sold to its owner, outbid otherwise.
    module PlayerOrders
      RECENT_FOR = 7.days
      ENDED_STATUSES = %w[served expired cancelled beaten].freeze
      IN_PROGRESS = %w[open bid].freeze

      Groups = Data.define(:in_progress, :recent)
      Row = Data.define(:token, :card, :price, :expires_at, :rarities, :duration_days, :status, :ended_at, :seller, :served, :listed_above, :listing_token)
      ListedAbove = Data.define(:seller, :amount, :token)
      Auction = Data.define(:token, :status, :leader_id, :ends_at, :updated_at)

      def self.call(player:, locale:, now: Time.current)
        orders = shown(player, now).order(:expires_at, :id).joins(:settings)
          .pluck(:id, :token, :card_id, :price, :expires_at, "game_market_settings.order_duration_days", :status, :updated_at, :seller_id, :served_card_season_id)
        faces = Catalog::LatestPublishedCardSeasons.call(orders.map(&:third))
        cards = Catalog::CardViews.call(faces.values + orders.filter_map(&:last), locale:)
        above = listed_above(player, orders.map(&:first))
        auctions = auctions_of(player, orders.map(&:first))
        sellers = Accounts::Player.where(id: orders.map { |*, seller_id, _served| seller_id }.compact + above.values.map(&:first)).index_by(&:id)
        rarities = OrderRarities.call(orders.map(&:first))
        rows = orders.filter_map do |id, token, card_id, price, expires_at, duration_days, status, updated_at, seller_id, served_card_season_id|
          card = cards[faces[card_id]]
          next unless card

          auction = auctions[id]
          standing = standing_of(status, auction, player)
          Row.new(token:, card:, price:, expires_at: standing == "bid" ? auction.ends_at : expires_at, rarities: rarities[id], duration_days:, status: standing,
            ended_at: ended_at(standing, status, auction, updated_at), seller: sellers[seller_id], served: cards[served_card_season_id],
            listed_above: above_row(above[id], sellers), listing_token: auction&.token)
        end
        in_progress, recent = rows.partition { IN_PROGRESS.include?(it.status) }
        Groups.new(in_progress: in_progress.sort_by.with_index { |row, position| [ row.expires_at, position ] }, recent: recent.sort_by(&:ended_at).reverse)
      end

      def self.shown(player, now)
        mine = Order.where(player_id: player.id)
        since = now - RECENT_FOR
        in_auction = Listing.where(status: "open").or(Listing.where(updated_at: since..))
        mine.where(status: "open").or(mine.where(status: ENDED_STATUSES, updated_at: since..)).or(mine.where(status: "bid", listing_id: in_auction.select(:id)))
      end
      private_class_method :shown

      def self.auctions_of(player, order_ids)
        Order.where(player_id: player.id, id: order_ids).joins(:listing)
          .pluck(:id, "game_market_listings.token", "game_market_listings.status", "game_market_listings.leader_id", "game_market_listings.ends_at",
            "game_market_listings.updated_at").to_h { |order_id, *rest| [ order_id, Auction.new(*rest) ] }
      end
      private_class_method :auctions_of

      def self.standing_of(status, auction, player)
        return status unless %w[bid beaten].include?(status)
        return "outbid" unless status == "bid" && auction&.leader_id == player.id

        { "open" => "bid", "sold" => "won" }.fetch(auction.status, "outbid")
      end
      private_class_method :standing_of

      def self.ended_at(standing, status, auction, updated_at)
        return if standing.in?(IN_PROGRESS)

        status == "bid" && auction ? auction.updated_at : updated_at
      end
      private_class_method :ended_at

      def self.listed_above(player, order_ids)
        Notice.listed_above_order.where(player_id: player.id, order_id: order_ids).joins(:listing).merge(Listing.open_now)
          .pluck(:order_id, :other_player_id, :amount, "game_market_listings.token").to_h { |order_id, *rest| [ order_id, rest ] }
      end
      private_class_method :listed_above

      def self.above_row(above, sellers)
        seller_id, amount, token = above
        ListedAbove.new(seller: sellers[seller_id], amount:, token:) if above
      end
      private_class_method :above_row

      def self.open_on(player, card_id) = Order.find_by(player_id: player.id, card_id:, status: "open")
    end
  end
end
