module Game
  module Market
    module ListingOutcome
      Closing = Data.define
      Outcome = Data.define(:kind, :card, :winner, :price, :surplus, :received, :buy_now)

      WITHOUT_SALE = { "unsold" => :no_bid, "cancelled" => :cancelled, "withdrawn" => :withdrawn }.freeze

      def self.call(token:, viewer:, locale:)
        listing = Listing.where(token: token.to_s).select(:id, :status, :ends_at, :card_season_id, :seller_id, :leader_id, :final_price, :buy_now_price).first
        return unless listing
        return (Closing.new if listing.ends_at <= Time.current) if listing.status == "open"

        card = Catalog::CardViews.call([ listing.card_season_id ], locale:)[listing.card_season_id]
        kind = WITHOUT_SALE[listing.status]
        return outcome(kind, card) if kind

        sold(listing, viewer, card)
      end

      def self.outcome(kind, card, winner: nil, price: nil, surplus: 0, received: 0, buy_now: false)
        Outcome.new(kind:, card:, winner:, price:, surplus:, received:, buy_now:)
      end

      def self.sold(listing, viewer, card)
        winner = Accounts::Player.find(listing.leader_id)
        price = listing.final_price
        buy_now = listing.buy_now_price == price
        shared = { winner:, price:, buy_now: }
        if viewer&.id == winner.id
          outcome(buy_now ? :bought : :won, card, **shared, surplus: [ surplus_of(listing, price), 0 ].max)
        elsif viewer&.id == listing.seller_id
          outcome(:seller_sold, card, **shared, received: received_by(listing, viewer))
        else
          outcome(lost?(listing, viewer) ? :lost : :viewer_sold, card, **shared)
        end
      end

      def self.surplus_of(listing, price) = Listing.where(id: listing.id).pick(:leader_maximum) - price

      def self.received_by(listing, seller)
        LedgerEntry.where(listing_id: listing.id, player_id: seller.id, kind: %w[sale commission]).sum(:available_delta)
      end

      def self.lost?(listing, viewer) = !viewer.nil? && Bid.where(listing_id: listing.id, player_id: viewer.id, outcome: "lost").exists?

      private_class_method :outcome, :sold, :surplus_of, :received_by, :lost?
    end
  end
end
