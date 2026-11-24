module Game
  module Market
    module OutbidCount
      def self.call(player)
        Listing.open_now.where(id: Bid.public_outcomes.where(player_id: player.id).select(:listing_id))
          .where("seller_id IS DISTINCT FROM ? AND leader_id IS DISTINCT FROM ?", player.id, player.id).count
      end
    end
  end
end
