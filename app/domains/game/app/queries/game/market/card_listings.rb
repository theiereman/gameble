module Game
  module Market
    module CardListings
      Row = Data.define(:token, :card, :current_price, :ends_at, :offers, :seller)

      def self.call(card_id, locale:)
        found = Listing.open_now.where(card_season_id: Catalog::CardSeason.where(card_id:).select(:id)).order(:ends_at, :id)
          .pluck(:id, :token, :card_season_id, :current_price, :ends_at, :seller_id)
        cards = Catalog::CardViews.call(found.map(&:third), locale:)
        offers = OfferCounts.call(found.map(&:first))
        sellers = Accounts::Player.where(id: found.map(&:last)).index_by(&:id)
        found.filter_map do |id, token, card_season_id, current_price, ends_at, seller_id|
          card = cards[card_season_id]
          Row.new(token:, card:, current_price:, ends_at:, offers: offers[id], seller: sellers[seller_id]) if card
        end
      end
    end
  end
end
