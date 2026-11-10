module Game
  module Market
    module MarketNotices
      LIMIT = 5

      Line = Data.define(:kind, :token, :card, :other, :amount, :noticed_at)

      def self.call(player:, locale: I18n.locale)
        lines(Notice.where(player_id: player.id).order(noticed_at: :desc, id: :desc).limit(LIMIT).to_a, locale)
      end

      def self.outbid(player:, listing_ids:, locale: I18n.locale)
        lines(Notice.where(player_id: player.id, listing_id: listing_ids, kind: "outbid").order(:id).to_a, locale)
      end

      def self.lines(notices, locale)
        return [] if notices.empty?

        listings = Listing.where(id: notices.map(&:listing_id)).pluck(:id, :token, :card_season_id).to_h { |id, token, card| [ id, [ token, card ] ] }
        titles = CardNames.call(listings.values.map(&:last), locale:)
        others = Accounts::Player.where(id: notices.filter_map(&:other_player_id)).index_by(&:id)
        notices.map do |notice|
          token, card = listings.fetch(notice.listing_id)
          Line.new(kind: notice.kind.to_sym, token:, card: titles[card]&.title, other: others[notice.other_player_id], amount: notice.amount,
            noticed_at: notice.noticed_at)
        end
      end

      private_class_method :lines
    end
  end
end
