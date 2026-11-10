module Game
  module Market
    module ListingEnding
      include ListingReservation

      private

      def end_without_sale(listing, status, now)
        leader_id = listing.leader_id
        released = listing.leader_maximum.to_i
        release_reservation(listing, now)
        listing.update!(status:, leader_id: nil, leader_maximum: nil)
        Ledger.post(release_entries(listing, leader_id, released))
        event = status == "withdrawn" ? ListingWithdrawn.new(data: { listing_id: listing.id, seller_id: listing.seller_id, leader_id:, released: }) : AuctionUnsold.new(data: { listing_id: listing.id, seller_id: listing.seller_id })
        publish(event, stream_name: stream_name(listing.seller_id))
      end

      def release_entries(listing, leader_id, released)
        return [] unless leader_id && released.positive?

        [ Ledger::Entry.new(player_id: leader_id, kind: :release, available_delta: released, committed_delta: -released, listing_id: listing.id, settings_id: listing.settings_id) ]
      end
    end
  end
end
