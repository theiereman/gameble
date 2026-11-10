module Game
  module Market
    class CloseAuction < Operation
      include AuctionSettlement
      include ListingEnding

      CLOSED_MEANWHILE = Dry::Monads::Failure(:listing_not_closable)

      def call(player:, listing_id:)
        player = step require_account(player)
        seen = step find_listing(player, listing_id)

        transaction do
          TradeLocks.players(*[ seen.seller_id, seen.leader_id ].compact)
          listing = Listing.lock.find(seen.id)
          now = Time.current
          step closable(listing, seen, now)
          step close(listing, now)
          listing
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def find_listing(player, listing_id)
        listing = Listing.find_by(id: listing_id, seller_id: player.id)
        listing ? Success(listing) : Failure(:listing_not_found)
      end

      def closable(listing, seen, now)
        listing.status == "open" && listing.ends_at <= now && listing.leader_id == seen.leader_id ? Success() : CLOSED_MEANWHILE
      end

      def close(listing, now)
        removed = Accounts::Player.where(id: [ listing.seller_id, listing.leader_id ].compact).select(&:removed?).map(&:id)
        if removed.include?(listing.seller_id) then end_without_sale(listing, "withdrawn", now)
        elsif listing.leader_id.nil? || removed.include?(listing.leader_id) then end_without_sale(listing, "unsold", now)
        else sell(listing, now)
        end
      end

      def sell(listing, now)
        price = listing.current_price
        winner_id = listing.leader_id
        entries = settle_sale(listing:, winner_id:, held: listing.leader_maximum, final_price: price, now:)
        Ledger.post(entries)
        publish_to_seller(listing, sold_event(listing:, winner_id:, final_price: price, surplus: listing.leader_maximum - price))
      end
    end
  end
end
