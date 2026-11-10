module Game
  module Market
    # Frees the copy a listing reserved, for the operations that end a listing without moving it.
    module ListingReservation
      private

      def release_reservation(listing, now)
        holding = TradeLocks.holdings(listing.seller_id, [ listing.card_season_id ]).fetch(listing.card_season_id)
        Holding.where(id: holding.id).update_all([ "reserved = reserved - 1, updated_at = ?", now ])
      end
    end
  end
end
