module Game
  module Market
    module MarketNotices
      LIMIT = 5

      Line = Data.define(:kind, :token, :card, :other, :amount, :noticed_at)

      def self.call(player:, locale: I18n.locale)
        notices = Notice.where(player_id: player.id).order(noticed_at: :desc, id: :desc).limit(LIMIT).to_a
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
    end
  end
end
