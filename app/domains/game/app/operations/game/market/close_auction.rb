module Game
  module Market
    # Ends a due auction exactly once: sold to its leader, left unsold, or withdrawn when its seller is gone. The job calls it in the seller's name.
    class CloseAuction < Operation
      include AuctionSettlement
      include ListingReservation

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

      def end_without_sale(listing, status, now)
        leader_id = listing.leader_id
        released = listing.leader_maximum.to_i
        release_reservation(listing, now)
        listing.update!(status:, leader_id: nil, leader_maximum: nil)
        Ledger.post(release_entries(listing, leader_id, released))
        event = status == "withdrawn" ? ListingWithdrawn.new(data: { listing_id: listing.id, seller_id: listing.seller_id, leader_id:, released: }) : AuctionUnsold.new(data: { listing_id: listing.id, seller_id: listing.seller_id })
        publish_to_seller(listing, event)
      end

      def release_entries(listing, leader_id, released)
        return [] unless leader_id && released.positive?

        [ Ledger::Entry.new(player_id: leader_id, kind: :release, available_delta: released, committed_delta: -released, listing_id: listing.id, settings_id: listing.settings_id) ]
      end
    end
  end
end
