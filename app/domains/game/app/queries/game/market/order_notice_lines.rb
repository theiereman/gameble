module Game
  module Market
    # The notices about a player's buy orders: served with the edition received, expired, a listing above the order's price, or turned into a bid on a listing.
    module OrderNoticeLines
      LIMIT = 5

      Line = Data.define(:kind, :token, :listing_token, :card, :edition, :other, :amount, :noticed_at)

      def self.call(player:, locale: I18n.locale)
        lines(Notice.where(player_id: player.id).where.not(order_id: nil).order(noticed_at: :desc, id: :desc).limit(LIMIT).to_a, locale)
      end

      def self.of_orders(player_id:, order_ids:, kinds:, locale: I18n.locale)
        lines(Notice.where(player_id:, order_id: order_ids, kind: kinds).order(:id).to_a, locale)
      end

      def self.lines(notices, locale)
        return [] if notices.empty?

        orders = Order.where(id: notices.map(&:order_id)).pluck(:id, :token, :card_id, :served_card_season_id).to_h { |id, *rest| [ id, rest ] }
        listings = Listing.where(id: notices.filter_map(&:listing_id)).pluck(:id, :token, :card_season_id).to_h { |id, *rest| [ id, rest ] }
        faces = Catalog::LatestPublishedCardSeasons.call(orders.values.map(&:second))
        editions = notices.to_h { [ it.id, edition_of(it, orders.fetch(it.order_id), listings[it.listing_id], faces) ] }
        cards = Catalog::CardViews.call(editions.values.compact, locale:)
        others = Accounts::Player.where(id: notices.filter_map(&:other_player_id)).index_by(&:id)
        notices.filter_map do |notice|
          edition = cards[editions[notice.id]]
          next unless edition

          Line.new(kind: notice.kind.to_sym, token: orders.fetch(notice.order_id).first, listing_token: listings[notice.listing_id]&.first,
            card: edition.title, edition:, other: others[notice.other_player_id], amount: notice.amount, noticed_at: notice.noticed_at)
        end
      end

      def self.edition_of(notice, order, listing, faces)
        _token, card_id, served_card_season_id = order
        case notice.kind
        when "order_served" then served_card_season_id
        when "listed_above_order", "order_leads", "order_beaten" then listing&.second
        else faces[card_id]
        end
      end

      private_class_method :lines, :edition_of
    end
  end
end
