module Game
  module Market
    # The Annonce's one reader: a listing's public facts by its token, never the leader's maximum.
    module ListingByToken
      Detail = Data.define(:token, :status, :card, :seller, :leader, :current_price, :starting_price, :buy_now_price, :ends_at, :created_at)

      def self.call(token, locale:)
        listing = Listing.where(token: token.to_s).select(:token, :status, :card_season_id, :seller_id, :leader_id, :current_price,
          :starting_price, :buy_now_price, :ends_at, :created_at).first
        return unless listing

        card = Catalog::CardViews.call([ listing.card_season_id ], locale:)[listing.card_season_id]
        return unless card

        players = Accounts::Player.where(id: [ listing.seller_id, listing.leader_id ].compact).index_by(&:id)
        Detail.new(token: listing.token, status: listing.status, card:, seller: players.fetch(listing.seller_id), leader: players[listing.leader_id],
          current_price: listing.current_price, starting_price: listing.starting_price, buy_now_price: listing.buy_now_price,
          ends_at: listing.ends_at, created_at: listing.created_at)
      end
    end
  end
end
