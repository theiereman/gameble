module Game
  module Market
    # The running auctions where the player holds a public bid and does not lead.
    module OutbidCount
      def self.call(player)
        Listing.open_now.where(id: Bid.public_outcomes.where(player_id: player.id).select(:listing_id))
          .where.not(seller_id: player.id).where("leader_id IS DISTINCT FROM ?", player.id).count
      end
    end
  end
end
