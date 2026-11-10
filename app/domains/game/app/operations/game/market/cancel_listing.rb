module Game
  module Market
    class CancelListing < Operation
      include ListingReservation

      def call(player:, listing_id:)
        player = step require_player(player)

        transaction do
          step lock_bank(player)
          listing = step find_listing(player, listing_id)
          now = Time.current
          step cancellable(listing, now)
          release_reservation(listing, now)
          listing.update!(status: "cancelled")
          step publish(ListingCancelled.new(data: { listing_id: listing.id, seller_id: player.id }), stream_name: stream_name(player.id))
          listing
        end
      rescue ActiveRecord::Deadlocked
        step Failure(:market_busy)
      end

      private

      def find_listing(player, listing_id)
        listing = Listing.lock.find_by(id: listing_id, seller_id: player.id)
        listing ? Success(listing) : Failure(:listing_not_found)
      end

      def cancellable(listing, now)
        return Failure(:auction_ended) unless listing.status == "open" && listing.ends_at > now

        listing.leader_id.nil? ? Success() : Failure(:bid_standing)
      end
    end
  end
end
